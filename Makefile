gnatmake=gnatmake
options=-gnat83
TARGETS=imp3ada

all: $(TARGETS)

imp3ada: src/Parser.adb
	$(gnatmake) $(options) -o bin/imp3ada src/Parser.adb
	-rm *.o *.ali

clean:
	-rm *.o *.ali bin/$(TARGETS)
