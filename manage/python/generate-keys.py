import random
import string

def generate_password(length=36):
    """Generate a random password without problematic characters."""
    # Exclude single quote, double quote, and backslash
    characters = string.ascii_letters + string.digits + "!@#$%^&*()_+-={}[]|:;<>,.?/"
    password = ''.join(random.choice(characters) for i in range(length))
    return password

if __name__ == "__main__":
    num_users = int(input("Enter the number of users: "))
    for i in range(num_users):
        password = generate_password()
        print(f"Generated password for user {i + 1}: {password}")
