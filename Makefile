gnatmake=gnatmake
options=-gnat83
TARGETS=imp3ada

all: $(TARGETS)

imp3ada: Parser.adb
	$(gnatmake) $(options)  -o imp3ada Parser.adb

clean:
	-rm *.o *.ali $(TARGETS)
