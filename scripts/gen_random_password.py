#!/usr/bin/env python3

### IMPORTS ###
import argparse
import logging
import random
import string

### GLOBALS ###
LOWERS = list(string.ascii_lowercase)
UPPERS = list(string.ascii_uppercase)
DIGITS = list(string.digits)
CHARS = []
CHARS.extend(LOWERS)
CHARS.extend(UPPERS)
CHARS.extend(DIGITS)

### FUNCTIONS ###

### CLASSES ###

### MAIN ###
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", action = "store_true")
    parser.add_argument("--length", type = int, default = 24)
    args = parser.parse_args()

    # Set up logging
    logging.basicConfig(
        format = "%(asctime)s:%(levelname)s:%(name)s:%(funcName)s: %(message)s",
        level = logging.DEBUG if args.verbose else logging.INFO
    )
    logging.debug("Args: %s", args)

    # Generate Random Password
    length = int(args.length)
    logging.debug("Generating password:")
    logging.debug("  Length: %s", length)
    logging.debug("  Charset: %s", CHARS)

    tmp_pass = []
    for i in range(length):
        tmp_pass.append(random.choice(CHARS))
    new_pass = "".join(tmp_pass)
    logging.debug("New Password: '%s'", new_pass)

    print(new_pass)

if __name__ == "__main__":
    main()
