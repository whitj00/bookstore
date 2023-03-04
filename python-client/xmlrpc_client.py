import xmlrpc.client
import shlex

def get_result(result):
    if result["Status"] == "Success":
        print("[Success]", result["Value"] if result["Value"] else "")
    else:
        print("[Error]", result["ErrorDescription"][1])

def castable_to_int(value):
    try:
        _ = int(value)
        return True
    except ValueError:
        return False
    
def search(proxy, topic):
    get_result(proxy.search({"topic": topic}))

def lookup(proxy, item_number):
    if(castable_to_int(item_number) == False):
        print("Invalid argument. Please try again.")
    else:
        get_result(proxy.lookup({"item_number": int(item_number)}))

def buy(proxy, item_number):
    if(castable_to_int(item_number) == False):
        print("Invalid argument. Please try again.")
    else:
        get_result(proxy.buy({"item_number": int(item_number)}))

with xmlrpc.client.ServerProxy("http://127.0.0.1:8000/") as proxy:
    print("Welcome to the bookstore! We can support the following commands:")
    print("search <topic> - search for books by topic")
    print("lookup <item_number> - lookup a book by item number")
    print("buy <item_number> - buy a book by item number")
    print("quit - quit the bookstore")
    while True:
        # attribution: https://stackoverflow.com/questions/79968/split-a-string-by-spaces-preserving-quoted-substrings-in-python
        command = shlex.split(input("\n> "))
        if command[0] == "quit":
            break
        elif len(command) != 2:
            print("Invalid number of arguments. Please try again.")
            continue

        arg = command[1]
        if command[0] == "search":
            search(proxy,arg)
        elif command[0] == "lookup":
            lookup(proxy,arg)
        elif command[0] == "buy":
            buy(proxy,arg)
        else:
            print("Invalid command. Please try again.")
