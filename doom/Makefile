
FILES=				\
		doomdef.c \
		doomstat.c \
		dstrings.c \
		i_system.c		\
		tables.c			\
		f_finale.c		\
		f_wipe.c 		\
		d_main.c			\
		d_items.c		\
		g_game.c			\
		m_menu.c			\
		m_misc.c			\
		m_argv.c  		\
		m_bbox.c			\
		m_fixed.c		\
		m_swap.c			\
		m_cheat.c		\
		m_random.c		\
		am_map.c			\
		p_ceilng.c		\
		p_doors.c		\
		p_enemy.c		\
		p_floor.c		\
		p_inter.c		\
		p_lights.c		\
		p_map.c			\
		p_maputl.c		\
		p_plats.c		\
		p_pspr.c			\
		p_setup.c		\
		p_sight.c		\
		p_spec.c			\
		p_switch.c		\
		p_mobj.c			\
		p_telept.c		\
		p_tick.c			\
		p_saveg.c		\
		p_user.c			\
		r_bsp.c			\
		r_data.c			\
		r_draw.c			\
		r_main.c			\
		r_plane.c		\
		r_segs.c			\
		r_sky.c			\
		r_things.c		\
		w_wad.c			\
		wi_stuff.c		\
		v_video.c		\
		st_lib.c			\
		st_stuff.c		\
		hu_stuff.c		\
		hu_lib.c			\
		z_zone.c			\
		info.c				\
		i_net.c			\
		d_net.c			\
		stubs.c    \
		sounds.c	\
		s_sound.c		\
		i_sound.c \
		TermDriver.c

OBJECTS = $(patsubst %.c,obj/%.o,$(FILES))
BAKED = support/baked_texture_data.o support/baked_map_data.o


all: $(OBJECTS) $(BAKED) $(LIB) obj/lib.o support/rawwad_use.o
	/opt/riscv/bin/riscv32-unknown-linux-gnu-gcc i_main.c $^  -o emdoom -T flatfile-rv32id.lds -nostdlib -Wl,--gc-sections -Wno-error -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-implicit-int -march=rv32ima -nostartfiles -mabi=ilp32

obj/lib.o: $(wildcard ../lib/*.c)
	/opt/riscv/bin/riscv32-unknown-linux-gnu-gcc -nostdlib -Wl,--gc-sections -Wno-error -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-implicit-int -march=rv32ima -nostartfiles -mabi=ilp32 -c -o $@ ../lib/lib.c

support/rawwad_use.o : support/rawwad_use.c
	/opt/riscv/bin/riscv32-unknown-linux-gnu-gcc -nostdlib -Wl,--gc-sections -Wno-error -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-implicit-int -march=rv32ima -nostartfiles -mabi=ilp32 -c -o $@ $^

support/baked_map_data.o : support/baked_map_data.c
	/opt/riscv/bin/riscv32-unknown-linux-gnu-gcc -nostdlib -Wl,--gc-sections -Wno-error -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-implicit-int -march=rv32ima -nostartfiles -mabi=ilp32 -c -o $@ $^

support/baked_texture_data.o : support/baked_texture_data.c
	/opt/riscv/bin/riscv32-unknown-linux-gnu-gcc -nostdlib -Wl,--gc-sections -Wno-error -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-implicit-int -march=rv32ima -nostartfiles -mabi=ilp32 -c -o $@ $^

obj/%.o: ./%.c
	/opt/riscv/bin/riscv32-unknown-linux-gnu-gcc -c -o $@ $< -nostdlib -Wl,--gc-sections -Wno-error -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-implicit-int -march=rv32ima -nostartfiles -mabi=ilp32 -DDISABLE_NETWORK
