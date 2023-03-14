bookstore
======

# Bulding

## Install Dependencies

    opam install core async caqti-async rpclib-async caqti-driver-sqlite3 cohttp-async core_unix ppx_deriving_rpc

## Build

    dune build --profile release
    cp _build/default/bin/main.exe bookstore

# Running

## Database

### Create
    ./bookstore db create

### Delete
    ./bookstore db drop

### Reset
    ./bookstore db reset

### Using a custom database
    ./bookstore db [cmd] -db "sqlite3:///tmp/custom.db"

## Server

### Start

    ./bookstore server start
    ./bookstore server start -daemon
    ./bookstore server start -db "sqlite3:///tmp/custom.db"
    ./bookstore server start -port 8888

### Logs

    ./bookstore server logs

### Restock

    ./bookstore server restock -item-number 12365
    ./bookstore server restock -item-number 12365 -quantity n

### Set Price
    
    ./bookstore server update -item-number 12365 -price 10.55

## Client

### Search Books

    ./bookstore client search -topic "distributed"
    ./bookstore client search -title "distributed" -host localhost -port 8000

### Lookup Book

    ./bookstore client lookup -item-number 12365

### Buy Book

    ./bookstore client buy -item-number 12365 -quantity 1

### Interactive Input

    ./bookstore client repl

```
base ❯ ./bookstore client repl
Welcome to the bookstore! We can support the following commands:
search <topic> - search for books by topic
lookup <item_number> - lookup a book by item number
buy <item_number> - buy a book by item number
help - print this prompt again
quit - quit the bookstore

> search "college"
12498: Cooking for the Impatient Undergraduate
12365: Surviving College

> lookup 12498
Title: Cooking for the Impatient Undergraduate
Topic: college life
Remaining Stock: 5
Price: 10.00

> buy 12498
Bought book 12498
```


## Benchmarking Examples

### Time Buy Command (500 requests/10 concurrent)

    ./bookstore client time buy -item-number 12498 -n 500 -c 10 

### Time Buy Command (100 sequential requests, remote)

    ./bookstore client time buy -item-number 12498 -n 100 -c 1 -host bagual.cs.williams.edu