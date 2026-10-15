-- Runs computer_space_top and dumps one line per game clock:
--   hsync vsync hblank vblank video(3..0)
-- to the file given by generic DUMP_FILE, for FRAMES frames after reset.
--
-- Game clock 5.8333 MHz (clk_vid 23.333 MHz / 4, as on the DE1).
-- A coin and a start press are injected so gameplay frames get drawn.

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

entity tb_core is
	generic (
		DUMP_FILE  : string  := "core_dump.txt";
		FRAMES     : integer := 26;
		SKIP_FRAMES: integer := 1
	);
end tb_core;

architecture sim of tb_core is
	signal clock_50  : std_logic := '0';
	signal game_clk  : std_logic := '0';
	signal reset     : std_logic := '1';
	signal coin, start : std_logic := '0';
	signal hsync, vsync, hblank, vblank : std_logic;
	signal video     : std_logic_vector(3 downto 0);
	signal done      : boolean := false;
begin
	clock_50 <= not clock_50 after 10 ns when not done;
	game_clk <= not game_clk after 85.714 ns when not done;   -- 5.8333 MHz

	dut : entity work.computer_space_top
	port map (
		reset => reset, clock_50 => clock_50, game_clk => game_clk,
		signal_ccw => '0', signal_cw => '0', signal_thrust => '0',
		signal_fire => '0', signal_start => start, signal_coin => coin,
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

	dump : process
		file f       : text open write_mode is DUMP_FILE;
		variable l   : line;
		variable vs_old : std_logic := '0';
		variable frame  : integer := 0;
		function b(s : std_logic) return character is
		begin
			if s = '1' then return '1'; else return '0'; end if;
		end function;
	begin
		wait until reset = '0';
		loop
			wait until rising_edge(game_clk);
			-- sample mid-period, as the DE1 top does
			wait for 60 ns;
			if vsync = '1' and vs_old = '0' then
				frame := frame + 1;
				report "frame " & integer'image(frame);
				if frame > SKIP_FRAMES + FRAMES then
					done <= true;
					wait;
				end if;
			end if;
			vs_old := vsync;
			if frame > SKIP_FRAMES then
				write(l, b(hsync)); write(l, b(vsync));
				write(l, b(hblank)); write(l, b(vblank));
				write(l, b(video(3))); write(l, b(video(2)));
				write(l, b(video(1))); write(l, b(video(0)));
				writeline(f, l);
			end if;
		end loop;
	end process;
end sim;
