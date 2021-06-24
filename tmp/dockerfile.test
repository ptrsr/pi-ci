FROM ubuntu:20.04 as builder
ARG $FILE_PATH=/test.txt
RUN touch $FILE_PATH
CMD cp $FILE_PATH ./

# Test 123
# ---------------------------
FROM ubuntu:20.04 as emulator
CMD echo "Hello, world!"
