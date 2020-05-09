#!/bin/bash

echo "Search for? (subject: to: from: body: cc: bcc:)"
read search
# In case I forget and put commas, or put a space after the colon
search=$(echo "$search" | sed 's/: /:/' | sed 's/,/ /')
# There are no quotes around the variable here ON PURPOSE
mu find --clearlinks --skip-dups --include-related --threads --format=links --linksdir=~/.mu/results $search
echo "Searching..... press F9 to move to that mailbox"
