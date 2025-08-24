ShootScheulde is an application and website for helping shooters find shooting events to participate in. The style is minimalist, yet elegant, leveraging Retool's default CSS and layout styling. Our future applications on different platforms should mirror this appraoch.

The parts of the application include:

* Worker process application for downloading shoot schedule data from the NSSA-NSCA, which is distributed in excel sheets. The worker processes and database for the shoot data is hosted on Heroku.
* Web application written in Retool and is the reference application for the other implementations
* A native application for iOS written in Swift and SwiftUI
* A login web application that aids users in using a Google login to access the applciation and provide identity. In the future, other login methods will be supported.

The Retool, Login, and Worker applications are already in production and being utilize by users. The main next TODOs are to:

* Implement an iOS application that mirrors the mobile-optimized web application written in Retool.
* Implement map marker popovers in the Retool application.
* Build a workflow and processes for outreach to club and event managers. 

Here are other feature ideas that are in my TODO list, as well as feature ideas and future integations.


TODO:
- DONE: Python scripts hosted (e.g. in Retool workflow or other) and tested
- DONE: Remove AI summaries
- DONE: Retool licensing for consumer apps
- DONE: Retool portal enablement
- DONE: Conditional logic to hide mark features (table, mark button) if no user ID is present
- DONE: Save marks to LocalStorage
- Disconnect mark button logic from database logic
- Logging / metrics for mark activity (e.g. replace the mark activity with database update calls)
- Restore / bootstrap (dump the PG setup scripts)
- Port Retool mobile app to native IOS
- Fivvr / Conversion (??)
- DONE: Postgres schema dump (tables, indexes, PL sql triggers)
- Update queries to show stats by region, affiliation, states, months in the drop downs
- Stats page showing how many shoots by dimension (NSCA, NSSA, months, states, notable, etc.)
- Page for club shoots. A bespoke page that only shows a particular club’s upcoming shoots. Could show this in list and calendar mode, starting with list.
- When marked shoots are selected, ignore the search filters and note that marked shoots are selected and to unselect marked shoots to see all shoots

Bugs
- Issue in shoots detail around marking / unmarking on the first unmarked; may need to consider refactors that:
    - Set a variable for the shoot to show in detail; this helps in scenarios where all marked shoots are removed and the detail view shows, which results in the detail view not being able to show details because selected row is invalid;
    - Any other detail show issues where the table selected row becomes invalid;
    - Need to refactor the change handler of the marked shoots, perhaps as a JS query that handles setting the state with additional scope provided;
    - Also needed to be able to show detail from map view, which doesn’t have access to the table / current row;

Feature Ideas
- Log activity (where to … postgres, log files, a lake, redis?)
- Identity (register via email, cell, member number)
- Add feedback
- Store filter settings in cookies; using Retool’s localStorage, key/values or key/objects can be stored; so, implementation roughly requires the creation of a JS object that contains the filter settings for affiliation (list), months (list), notable (bool), and future (bool); on each change, call a function to save the object to local storage; create a JS class in the application’s context; on start (TBD: where is this hook), if there is a localStorage(“filters” object set, use that to apply filter settings to the application;
    - Documentation for localStorage
- Map marker colors by shoot type
- Map view for mobile
- ! Map marker hover info and popovers (unable with map box component)
- Static color set for affiliation.
- Filter selections for regions (which set the state selection lists); west, north central, south central, northeast, southeast, Jamaica, PR, AK, HI
- Start / end date simplification (e.g. May 6 - 9, 2024 or Dec 31, 24 - Jan 3, 24)
- drop: Database migration to Retool postgres (may require paying more)
- Get cron working properly so I don’t have to use sleep commands in the python script
- Add quick select links for quarters (Q1 - Q4)
- Add mailto for the club manager

iOS App
- A script that converts shoot events into a sqlite database
- A framework that reads events from the sqlite database
- A set of queries that operate on sqlite databases and support the app filter options
- A serverless feature allowing Sign in with Apple 
- A sync feature using Firebase that allows syncing of marked shoots across mobile and web

Marketing Plan
- YouTube account with explainer video.
- Bot mail to introduce club managers to ShootsDB, noting the shoots listed and links to update shoot info.
- Bot mail to club managers introducing them to ShootsDB and asking them to submit a description for a select set of shoots (the high profile registered shoots)
- Bot mail to club managers with a link introducing them to their own club’s shoot list and schedule.
- Bot mail asking club managers for their feedback on ShootsDB and asking them if this would be helpful to managing their shoot info?

On Marketing Tools
- Can feed club contacts into Campaigns;
- Use campaigns to create an on boarding series of comms;
- Route the replies to these campaigns to the Robot inbox (and possibly wire up other triggers from that);
- Q: will tracking of who has received what be needed in Retool? Presumably campaigns can handle unique sending to ensure a given contact doesn’t trigger a second workflow;
- May need to hash the club info (name, city, sate) as a unique identifier; use the hash plus a query to connect the hash in a URL to a club and their events;

ATA Integration 

Gateway IP address as of Jan 19, 2025: 73.95.16.144

- API Key: 21laTa!V&3JKbkP#0G2uMLoei8BGn*$d
- The max return on any of the endpoints is 5000 records.  
- https://dataapi.shootata.com/api/ShooterData/ShootListByDate?begin=5/1/2023&end=6/1/2023&gunclubnumber=010000  Gives you a list of shoots at a club.  If you leave off the gunclubnumber parameter: https://dataapi.shootata.com/api/ShooterData/ShootListByDate?begin=5/1/2023&end=6/1/2023  This will give you all shoots in the date range.
- https://dataapi.shootata.com/api/ShooterData?pageNumber=1&pageSize=10000  is meant to be an initial pull of data and not to be used daily and should only be used in the late evening. Summary of all years together
- https://dataapi.shootata.com/api/ShooterData/Updated?updatedDate=2/5/2024&pageNumber=1&pageSize=50  This gives you information based on when the ATA office received shoot data.  This is what would be run daily after the initial load from above to update Summary Data
- https://dataapi.shootata.com/api/ShooterData/MemberYearData?targetyear=2023&atanumber=2069620 is probably the best/quickest way to get shoot data on a shooter for a single target year.  Summary Data
- https://dataapi.shootata.com/api/ShooterData/MemberShootData?enteredDate=8/13/2023&pageNumber=1&pageSize=50&atanumber=1311206 ; ATANumber is an optional parameter but will limit the results for the time period to the person selected. Gets more detailed information for each event.  Detail information
- https://dataapi.shootata.com/api/ShooterData/Gunclubs - Gives you information on all Gun Clubs
- Attached you will find the Postman collection on the endpoints currently available.
