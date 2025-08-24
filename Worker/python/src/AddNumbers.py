# File name: AddTwoNumbers.py

def main():
    try:
        # Get the first number from the user
        num1 = float(input("Enter the first number: "))

        # Get the second number from the user
        num2 = float(input("Enter the second number: "))

        # Add the two numbers
        result = num1 + num2

        # Print the result
        print(f"The sum of {num1} and {num2} is {result}")
    except ValueError:
        print("Invalid input. Please enter numeric values.")


if __name__ == "__main__":
    main()
