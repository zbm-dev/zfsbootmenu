#!/bin/bash

# print an "empty" string to the screen to force it to recalculate
# with out this, EFI frame buffers will possibly have the wrong size

echo -e "\033[0;30m ... \033[0m"
