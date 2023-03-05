import xmlrpc.client
import shlex

def get_result(result):
    if result["Status"] == "Success":
        print("[Success]", result["Value"] if result["Value"] else "")
    else:
        print("[Error]", result["ErrorDescription"][1])

def castable_to_int(value):
    try:
        int(value)
        return True
    except ValueError:
        return False
    
def search(proxy, topic):
    get_result(proxy.search({"topic": topic}))

def lookup(proxy, item_number):
    if(castable_to_int(item_number) == False):
        print("Argument must be an integer. Please try again.")
    else:
        get_result(proxy.lookup({"item_number": int(item_number)}))

def buy(proxy, item_number):
    if(castable_to_int(item_number) == False):
        print("Argument must be an integer. Please try again.")
    else:
        get_result(proxy.buy({"item_number": int(item_number)}))

def repl(proxy):
    print("Welcome to the bookstore! We can support the following commands:")
    print("search <topic> - search for books by topic")
    print("lookup <item_number> - lookup a book by item number")
    print("buy <item_number> - buy a book by item number")
    print("help - print this prompt again")
    print("quit - quit the bookstore")
    while True:
        # https://stackoverflow.com/questions/79968
        command = shlex.split(input("\n> "))

        if command[0] == "quit":
            break
        if command[0] == "help":
            continue
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

if __name__ == "__main__":
    with xmlrpc.client.ServerProxy("http://127.0.0.1:8000/") as proxy:
        repl(proxy)