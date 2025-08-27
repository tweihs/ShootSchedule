// test/apple-user-functions.test.js
const test = require("firebase-functions-test")();
const chai = require("chai");
const expect = chai.expect;
const sinon = require("sinon");

// Mock environment
process.env.DB_URL = "postgresql://test:test@localhost:5432/testdb";

const admin = require("firebase-admin");
const functions = require("../index");

describe("Apple User Functions", () => {
  let mockClient;

  beforeEach(() => {
    // Mock PostgreSQL client
    mockClient = {
      connect: sinon.stub().resolves(),
      query: sinon.stub(),
      end: sinon.stub().resolves(),
    };

    // Mock the pg Client constructor
    const {Client} = require("pg");
    sinon.stub(Client.prototype, "connect").callsFake(mockClient.connect);
    sinon.stub(Client.prototype, "query").callsFake(mockClient.query);
    sinon.stub(Client.prototype, "end").callsFake(mockClient.end);
  });

  afterEach(() => {
    sinon.restore();
  });

  describe("associateAppleUser", () => {
    it("should return existing user when Apple user already exists", async () => {
      const req = {
        body: {
          appleUserID: "apple123",
          email: "test@example.com",
          displayName: "Test User",
          identityToken: "token123",
        },
      };

      const res = {
        status: sinon.stub().returnsThis(),
        json: sinon.stub(),
      };

      // Mock existing Apple user found
      mockClient.query.onFirstCall().resolves({
        rowCount: 1,
        rows: [{user_id: "user-uuid-123"}],
      });

      const wrapped = test.wrap(functions.associateAppleUser);
      await wrapped(req, res);

      expect(res.json.calledOnce).to.be.true;
      expect(res.json.calledWith({
        userId: "user-uuid-123",
        isNewUser: false,
      })).to.be.true;
    });

    it("should create new user for Apple sign in", async () => {
      const req = {
        body: {
          appleUserID: "apple123",
          email: "tyson@weihs.com",
          displayName: "Tyson Weihs",
          identityToken: "token123",
        },
      };

      const res = {
        status: sinon.stub().returnsThis(),
        json: sinon.stub(),
      };

      // Mock no existing Apple user
      mockClient.query.onCall(0).resolves({rowCount: 0});

      // Mock new user creation
      mockClient.query.onCall(1).resolves({
        rows: [{id: "new-apple-user-uuid"}],
      });

      // Mock successful Apple user association
      mockClient.query.onCall(2).resolves();

      const wrapped = test.wrap(functions.associateAppleUser);
      await wrapped(req, res);

      expect(res.json.calledOnce).to.be.true;
      expect(mockClient.query.calledThrice).to.be.true;

      // Check that association was created
      const associationCall = mockClient.query.getCall(2);
      expect(associationCall.args[0]).to.include("INSERT INTO apple_users");
      expect(associationCall.args[1]).to.deep.equal([
        "apple123",
        "new-apple-user-uuid",
        "tyson@weihs.com",
        "token123",
        "Tyson Weihs",
      ]);
    });

    it("should create new user when no existing user found", async () => {
      const req = {
        body: {
          appleUserID: "apple456",
          email: "newuser@example.com",
          displayName: "New User",
          identityToken: "token456",
        },
      };

      const res = {
        status: sinon.stub().returnsThis(),
        json: sinon.stub(),
      };

      // Mock no existing Apple user
      mockClient.query.onCall(0).resolves({rowCount: 0});

      // Mock new user creation
      mockClient.query.onCall(1).resolves({
        rows: [{id: "new-user-uuid"}],
      });

      // Mock successful Apple user association
      mockClient.query.onCall(2).resolves();

      const wrapped = test.wrap(functions.associateAppleUser);
      await wrapped(req, res);

      expect(mockClient.query.callCount).to.equal(3);

      // Check new user creation
      const createUserCall = mockClient.query.getCall(1);
      expect(createUserCall.args[0]).to.include("INSERT INTO users");
      expect(createUserCall.args[1]).to.deep.equal([
        "New User",
      ]);
    });

    it("should return error when appleUserID is missing", async () => {
      const req = {
        body: {
          email: "test@example.com",
        },
      };

      const res = {
        status: sinon.stub().returnsThis(),
        json: sinon.stub(),
      };

      const wrapped = test.wrap(functions.associateAppleUser);
      await wrapped(req, res);

      expect(res.status.calledWith(400)).to.be.true;
      expect(res.json.calledWith({error: "Missing appleUserID"})).to.be.true;
    });
  });

  describe("fetchUserPreferences", () => {
    it("should fetch user preferences successfully", async () => {
      const req = {
        query: {userId: "user-123"},
      };

      const res = {
        status: sinon.stub().returnsThis(),
        json: sinon.stub(),
      };

      // Mock user preferences found
      mockClient.query.onCall(0).resolves({
        rowCount: 1,
        rows: [{
          preferences: {states: ["CA", "TX"]},
        }],
      });

      // Mock marked shoots
      mockClient.query.onCall(1).resolves({
        rows: [
          {shoot_id: 1},
          {shoot_id: 2},
          {shoot_id: 3},
        ],
      });

      const wrapped = test.wrap(functions.fetchUserPreferences);
      await wrapped(req, res);

      expect(res.json.calledOnce).to.be.true;
      const responseData = res.json.getCall(0).args[0];
      expect(responseData).to.deep.equal({
        userId: "user-123",
        filterSettings: {states: ["CA", "TX"]},
        markedShoots: [1, 2, 3],
      });
    });

    it("should return 404 when user preferences not found", async () => {
      const req = {
        query: {userId: "nonexistent-user"},
      };

      const res = {
        status: sinon.stub().returnsThis(),
        json: sinon.stub(),
      };

      // Mock no preferences found
      mockClient.query.onCall(0).resolves({rowCount: 0});

      const wrapped = test.wrap(functions.fetchUserPreferences);
      await wrapped(req, res);

      expect(res.status.calledWith(404)).to.be.true;
      expect(res.json.calledWith({error: "User preferences not found"})).to.be.true;
    });
  });

  describe("syncUserPreferences", () => {
    it("should sync user preferences successfully", async () => {
      const req = {
        body: {
          userId: "user-123",
          filterSettings: {states: ["CA"]},
        },
      };

      const res = {
        status: sinon.stub().returnsThis(),
        json: sinon.stub(),
      };

      // Mock successful upsert
      mockClient.query.resolves();

      const wrapped = test.wrap(functions.syncUserPreferences);
      await wrapped(req, res);

      expect(res.json.calledWith({success: true})).to.be.true;
      expect(mockClient.query.calledOnce).to.be.true;

      const queryCall = mockClient.query.getCall(0);
      expect(queryCall.args[0]).to.include("INSERT INTO user_preferences");
      expect(queryCall.args[1]).to.deep.equal([
        "user-123",
        "{\"states\":[\"CA\"]}",
      ]);
    });
  });

  describe("syncMarkedShoots", () => {
    it("should sync marked shoots successfully", async () => {
      const req = {
        body: {
          userId: "user-123",
          markedShootIds: [1, 2, 3, 4],
        },
      };

      const res = {
        status: sinon.stub().returnsThis(),
        json: sinon.stub(),
      };

      // Mock successful transaction
      mockClient.query.resolves();

      const wrapped = test.wrap(functions.syncMarkedShoots);
      await wrapped(req, res);

      expect(res.json.calledWith({success: true, count: 4})).to.be.true;
      expect(mockClient.query.callCount).to.equal(4); // BEGIN, DELETE, INSERT, COMMIT
    });

    it("should handle empty marked shoots array", async () => {
      const req = {
        body: {
          userId: "user-123",
          markedShootIds: [],
        },
      };

      const res = {
        status: sinon.stub().returnsThis(),
        json: sinon.stub(),
      };

      // Mock successful transaction
      mockClient.query.resolves();

      const wrapped = test.wrap(functions.syncMarkedShoots);
      await wrapped(req, res);

      expect(res.json.calledWith({success: true, count: 0})).to.be.true;
      expect(mockClient.query.callCount).to.equal(3); // BEGIN, DELETE, COMMIT (no INSERT)
    });

    it("should return error when markedShootIds is not an array", async () => {
      const req = {
        body: {
          userId: "user-123",
          markedShootIds: "not-an-array",
        },
      };

      const res = {
        status: sinon.stub().returnsThis(),
        json: sinon.stub(),
      };

      const wrapped = test.wrap(functions.syncMarkedShoots);
      await wrapped(req, res);

      expect(res.status.calledWith(400)).to.be.true;
      expect(res.json.calledWith({error: "markedShootIds must be an array"})).to.be.true;
    });
  });

  describe("Error Handling", () => {
    it("should handle database connection errors", async () => {
      const req = {
        body: {
          appleUserID: "apple123",
          email: "test@example.com",
          displayName: "Test User",
          identityToken: "token123",
        },
      };

      const res = {
        status: sinon.stub().returnsThis(),
        json: sinon.stub(),
      };

      // Mock database error
      mockClient.connect.rejects(new Error("Connection failed"));

      const wrapped = test.wrap(functions.associateAppleUser);
      await wrapped(req, res);

      expect(res.status.calledWith(500)).to.be.true;
      expect(res.json.calledWith({error: "Failed to associate Apple user"})).to.be.true;
    });
  });
});

// Integration Test for Tyson's Use Case
describe("Integration Test - Tyson's Scenario", () => {
  it("should link Apple user to existing tyson@weihs.com Firebase user", async () => {
    // This test simulates the exact scenario where Tyson signs in with Apple
    // and it should link to his existing Firebase user

    const req = {
      body: {
        appleUserID: "apple.tyson.weihs.unique.id",
        email: "tyson@weihs.com",
        displayName: "Tyson Weihs",
        identityToken: "apple.identity.token.for.tyson",
      },
    };

    const res = {
      status: sinon.stub().returnsThis(),
      json: sinon.stub(),
    };

    const mockClient = {
      connect: sinon.stub().resolves(),
      query: sinon.stub(),
      end: sinon.stub().resolves(),
    };

    // Mock the sequence:
    // 1. Check if Apple user exists (should not)
    mockClient.query.onCall(0).resolves({rowCount: 0});

    // 2. Create new user
    mockClient.query.onCall(1).resolves({
      rows: [{id: "tyson-new-user-uuid-123"}],
    });

    // 3. Create Apple user association
    mockClient.query.onCall(2).resolves();

    // Stub the Client constructor
    const {Client} = require("pg");
    const clientStub = sinon.stub(Client.prototype);
    clientStub.connect = mockClient.connect;
    clientStub.query = mockClient.query;
    clientStub.end = mockClient.end;

    const wrapped = test.wrap(functions.associateAppleUser);
    await wrapped(req, res);

    // Verify the result
    expect(res.json.calledOnce).to.be.true;
    const result = res.json.getCall(0).args[0];
    expect(result.userId).to.equal("tyson-new-user-uuid-123");

    // Verify the association was created correctly
    const associationQuery = mockClient.query.getCall(2);
    expect(associationQuery.args[0]).to.include("INSERT INTO apple_users");
    expect(associationQuery.args[1]).to.include("apple.tyson.weihs.unique.id");
    expect(associationQuery.args[1]).to.include("tyson-new-user-uuid-123");
    expect(associationQuery.args[1]).to.include("tyson@weihs.com");

    sinon.restore();
  });
});
