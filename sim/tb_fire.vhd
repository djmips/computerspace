-- Plays a game far enough to fire a missile, and dumps the frames around the
-- shot in the same format as tb_core ("hs vs hb vb v3 v2 v1 v0" per game clock),
-- so render.py can draw them and the rocket and missile can be located.
--
-- Coin and start as in tb_core; the rocket appears at ~1.33 s. Times in ms.

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

entity tb_fire is
	generic (
		DUMP_FILE    : string  := "out/fire_dump.txt";
		THRUST_FROM  : integer := 1340;
		THRUST_TO    : integer := 1500;
		ROTATE_FROM  : integer := 0;     -- hold CW from ROTATE_FROM to ROTATE_TO
		ROTATE_TO    : integer := 0;
		FIRE_AT      : integer := 1900;
		DUMP_FROM    : integer := 1860;
		DUMP_FRAMES  : integer := 8
	);
end tb_fire;

architecture sim of tb_fire is
	signal clock_50  : std_logic := '0';
	signal game_clk  : std_logic := '0';
	signal reset     : std_logic := '1';
	signal coin, start, thrust, fire, cw : std_logic := '0';
	signal hsync, vsync, hblank, vblank : std_logic;
	signal video     : std_logic_vector(3 downto 0);
	signal done      : boolean := false;
begin
	clock_50 <= not clock_50 after 10 ns when not done;
	game_clk <= not game_clk after 85.714 ns when not done;   -- 5.8333 MHz

	dut : entity work.computer_space_top
	port map (
		reset => reset, clock_50 => clock_50, game_clk => game_clk,
		signal_ccw => '0', signal_cw => cw, signal_thrust => thrust,
		signal_fire => fire, signal_start => start, signal_coin => coin,
		sw_2playpercoin => '0', sw_replay => '0',
		hsync => hsync, vsync => vsync, hblank => hblank, vblank => vblank,
		video => video, audio => open
	);

	stim : process
	begin
		reset <= '1';
		wait for 1 us;
		reset <= '0';
		wait for 30 ms;
		coin <= '1';  wait for 100 ms;  coin <= '0';
		wait for 50 ms;
		start <= '1'; wait for 100 ms;  start <= '0';
		wait;
	end process;

	inputs : process
	begin
		wait for THRUST_FROM * 1 ms;
		thrust <= '1';
		wait for (THRUST_TO - THRUST_FROM) * 1 ms;
		thrust <= '0';
		wait;
	end process;

	rotate : process
	begin
		if ROTATE_TO > ROTATE_FROM then
			wait for ROTATE_FROM * 1 ms;
			cw <= '1';
			wait for (ROTATE_TO - ROTATE_FROM) * 1 ms;
			cw <= '0';
		end if;
		wait;
	end process;

	shoot : process
	begin
		wait for FIRE_AT * 1 ms;
		fire <= '1';
		wait for 100 ms;
		fire <= '0';
		wait;
	end process;

	dump : process
		file f       : text open write_mode is DUMP_FILE;
		variable l   : line;
		variable vs_old : std_logic := '0';
		variable frames : integer := -1;   -- -1 until DUMP_FROM, then counts frames
		function b(s : std_logic) return character is
		begin
			if s = '1' then return '1'; else return '0'; end if;
		end function;
	begin
		wait for DUMP_FROM * 1 ms;
		loop
			wait until rising_edge(game_clk);
			wait for 60 ns;
			if vsync = '1' and vs_old = '0' then
				frames := frames + 1;
				report "dump frame " & integer'image(frames);
				if frames > DUMP_FRAMES then
					done <= true;
					wait;
				end if;
			end if;
			vs_old := vsync;
			if frames >= 0 then
				write(l, b(hsync)); write(l, b(vsync));
				write(l, b(hblank)); write(l, b(vblank));
				write(l, b(video(3))); write(l, b(video(2)));
				write(l, b(video(1))); write(l, b(video(0)));
				writeline(f, l);
			end if;
		end loop;
	end process;
end sim;
