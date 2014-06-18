
GCC=gcc  -Wall -ggdb -lpq -I/usr/pgsql-9.3/include -L/usr/pgsql-9.3/lib -lpthread

all: ps_bgworker

ps_bgworker: main.c
	$(GCC) -o $@ $^

clean: 
	rm ps_bgworker
