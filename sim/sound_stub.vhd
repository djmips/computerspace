-- Silent stand-in for computer_space_sound in video simulations.
library ieee;
use ieee.std_logic_1164.all;

entity computer_space_sound is
port(
 clock_50 : in std_logic;
 reset    : in std_logic;
 sound_switch : in std_logic_vector(7 downto 0);
 saucer_missile_sound : in std_logic;
 rocket_missile_sound : in std_logic;
 turn_sound           : in std_logic;
 audio_gate : in std_logic;
 audio      : out integer range -32768 to 32767
);
end computer_space_sound;

architecture stub of computer_space_sound is
begin
	audio <= 0;
end stub;
