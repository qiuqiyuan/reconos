library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;

entity fifo32 is
	generic (
		C_FIFO32_DEPTH  : integer := 2048;
		C_ENABLE_ILA    : integer := 0
	);
	port (
		Rst : in std_logic;
		FIFO32_S_Clk : in std_logic;
		FIFO32_M_Clk : in std_logic;
		FIFO32_S_Data : out std_logic_vector(31 downto 0);
		FIFO32_M_Data : in std_logic_vector(31 downto 0);
		FIFO32_S_Fill : out std_logic_vector(15 downto 0);
		FIFO32_M_Rem : out std_logic_vector(15 downto 0);
		FIFO32_S_Rd : in std_logic;
		FIFO32_M_Wr : in std_logic
	);
end entity;

architecture implementation of fifo32 is

	component fifo32b_icon
	PORT (
		CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0)
	);
	end component;

	component fifo32b_ila
	PORT (
		CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		CLK : IN STD_LOGIC;
		DATA : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
		TRIG0 : IN STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
	end component;

	signal CONTROL : STD_LOGIC_VECTOR(35 DOWNTO 0);
	signal DATA    : STD_LOGIC_VECTOR(255 DOWNTO 0);
	signal TRIG    : STD_LOGIC_VECTOR(15 DOWNTO 0);
	
	function incptr(v : std_logic_vector) return std_logic_vector is
		variable result : std_logic_vector (v'length-1 downto 0);
	begin
		if v = C_FIFO32_DEPTH-1 then
			result := (others => '0');
		else
			result :=  v + 1;
		end if;
		return result;
	end;

	type MEM_T is array (0 to C_FIFO32_DEPTH-1) of std_logic_vector(31 downto 0);
	signal mem : MEM_T;
	
	type STATE_T is (EMPTY, RAM_EMPTY, RAM_ACTIVE_DELAY, RAM_NO_DELAY);
	signal state : STATE_T;
	
	signal wrptr : std_logic_vector(clog2(C_FIFO32_DEPTH)-1 downto 0);
	signal rdptr : std_logic_vector(clog2(C_FIFO32_DEPTH)-1 downto 0);
	signal rdptr_syn : std_logic_vector(clog2(C_FIFO32_DEPTH)-1 downto 0);
	signal remainder : std_logic_vector(clog2(C_FIFO32_DEPTH)-1  downto 0);
	signal fill      : std_logic_vector(clog2(C_FIFO32_DEPTH)-1  downto 0);
	signal pad       : std_logic_vector(15 - clog2(C_FIFO32_DEPTH) downto 0);
	signal delay     : std_logic_vector(31 downto 0);
	signal do        : std_logic_vector(31 downto 0);
	signal di        : std_logic_vector(31 downto 0);
	signal clk       : std_logic;
	signal we        : std_logic;
	signal sel_delay : std_logic;
	signal do_workaround : std_logic_vector(31 downto 0);
	
	signal FIFO32_S_Data_out : std_logic_vector(31 downto 0);
	signal FIFO32_S_Fill_out : std_logic_vector(15 downto 0);
	signal FIFO32_M_Rem_out  : std_logic_vector(15 downto 0);
begin

--------------------- CHIPSCOPE -------------------------
	
	GENERATE_ILA : if C_ENABLE_ILA = 1 generate

	icon_i : fifo32b_icon
	port map (
		CONTROL0 => CONTROL
	);
	
	ila_i : fifo32b_ila
	port map (
		CONTROL => CONTROL,
		CLK => clk,
		DATA => DATA,
		TRIG0 => TRIG
	);

	end generate;
	
	DATA(0) <= Rst;
	DATA(1) <= FIFO32_S_Rd;
	DATA(2) <= FIFO32_M_wr;
	DATA(3) <= sel_delay;
	DATA(4) <= we;
	DATA(8) <= '1' when state = EMPTY else '0';
	DATA(9) <= '1' when state = RAM_EMPTY else '0';
	DATA(10) <= '1' when state = RAM_ACTIVE_DELAY else '0';
	DATA(11) <= '1' when state = RAM_NO_DELAY else '0';
	DATA(31 downto 12) <= (others => '0');
	DATA(47 downto 32) <= FIFO32_S_Fill_out;
	DATA(63 downto 48) <= FIFO32_M_Rem_out;
	DATA(95 downto 64) <= FIFO32_S_Data_out;
	DATA(127 downto 96) <= FIFO32_M_Data;
	DATA(143 downto 128) <= pad & rdptr;
	DATA(159 downto 144) <= pad & wrptr;
	DATA(191 downto 160) <= do;
	DATA(223 downto 192) <= di;
	DATA(255 downto 224) <= delay;
	
	TRIG <= DATA(15 downto 0);

---------------------------------------------------------

	FIFO32_S_Data <= FIFO32_S_Data_out;
	FIFO32_S_Fill <= FIFO32_S_Fill_out;
	FIFO32_M_Rem  <= FIFO32_M_Rem_out;

	clk <= FIFO32_M_Clk;
	
	pad <= (others => '0');

	FIFO32_S_Fill_out <= pad & fill;
	FIFO32_M_Rem_out  <= pad & remainder;
	
	--FIFO32_S_Data <= delay when sel_delay = '1' else do;
	
	process(delay,sel_delay,do,fill)
	begin
		if fill = 0 then
			FIFO32_S_Data_out <= x"AFFEDEAD";
		else
			if sel_delay = '1' then
				FIFO32_S_Data_out <= delay;
			else
				FIFO32_S_Data_out <= do;
			end if;
		end if;
	end process;

	process(clk, rst)
	begin
		if rst = '1' then
			wrptr <= (others => '0');
			--do <= (others => '0');
		elsif rising_edge(clk) then
			if we = '1' then
				mem(CONV_INTEGER(wrptr)) <= di;
				wrptr <= incptr(wrptr);
			end if;
			rdptr_syn <= rdptr;
		end if;
	end process;
	
	-- This works just fine in simulation:
	--
	-- do <= mem(CONV_INTEGER(rdptr_syn));
	--
	-- Together with the process above this specifies a write-first dual port ram.
	-- According to the xilinx xst documentation the ram will be implemented using
	-- block ram resources.
	--
	-- Unfortunately, while a block ram implementation is indeed infered during synthesis,
	-- it will not implement write-first access (which contradicts the plain vhdl specification).
	-- This is a subtle bug that can be hard to find and can cost you days of debugging.
	-- This workaround implements write-first access in a way that works with xst:
	
	do_workaround <= mem(CONV_INTEGER(rdptr_syn));
	do <= di when rdptr = wrptr and we = '1' else do_workaround;
	
	process(clk, rst)
	begin
		if rst = '1' then
			fill <= (others => '0');
			remainder <= CONV_STD_LOGIC_VECTOR(C_FIFO32_DEPTH - 1,remainder'length);
			state <= EMPTY;
			rdptr <= (others => '0');
			sel_delay <= '1';
			delay <= (others => '0');
		elsif rising_edge(clk) then
		
			if FIFO32_M_Wr = '0' and FIFO32_S_Rd = '1' then
				fill <= fill - 1;
				remainder <= remainder + 1;
			end if;
			
			if FIFO32_M_Wr = '1' and FIFO32_S_Rd = '0' then
				fill <= fill + 1;
				remainder <= remainder - 1;
			end if;
			
			we <= '0';
		
			case state is
				when EMPTY =>
					sel_delay <= '1';
					if FIFO32_M_Wr = '1' then
						delay <= FIFO32_M_Data;
						state <= RAM_EMPTY;
					end if;
				
				when RAM_EMPTY =>
					sel_delay <= '1';
					
					if FIFO32_M_Wr = '0' and FIFO32_S_Rd = '1' then
						state <= EMPTY;
					end if;
					
					if FIFO32_M_Wr = '1' and FIFO32_S_Rd = '0' then
						we <= '1';
						di <= FIFO32_M_Data;
						state <= RAM_ACTIVE_DELAY;
						
					end if;
				
					if FIFO32_M_Wr = '1' and FIFO32_S_Rd = '1' then
						delay <= FIFO32_M_Data;
					end if;
					
				when RAM_ACTIVE_DELAY =>
					sel_delay <= '1';
					
					if FIFO32_M_Wr = '0' and FIFO32_S_Rd = '1' then
						--FIFO32_S_Data_out <= delay;
						delay <= do;
						rdptr <= incptr(rdptr);
						sel_delay <= '0';
						if fill = 2 then
							state <= RAM_EMPTY;
						else
							state <= RAM_NO_DELAY;
						end if;
					end if;
					
					if FIFO32_M_Wr = '1' and FIFO32_S_Rd = '0' then
						we <= '1';
						di <= FIFO32_M_Data;
					end if;
				
					if FIFO32_M_Wr = '1' and FIFO32_S_Rd = '1' then
						we <= '1';
						di <= FIFO32_M_Data;
						--FIFO32_S_Data_out <= delay;
						delay <= do;
						rdptr <= incptr(rdptr);
						sel_delay <= '0';
						state <= RAM_NO_DELAY;
					end if;
					
					
				when RAM_NO_DELAY =>
					
					sel_delay <= '0';
					delay <= do;
				
					if FIFO32_M_Wr = '0' and FIFO32_S_Rd = '1' then
						--FIFO32_S_Data_out <= do;
						if fill = 1 then
							state <= EMPTY;
						else
							rdptr <= incptr(rdptr);
						end if;
					end if;
					
					if FIFO32_M_Wr = '1' and FIFO32_S_Rd = '0' then
						we <= '1';
						di <= FIFO32_M_Data;
						sel_delay <= '1';
						state <= RAM_ACTIVE_DELAY;
					end if;
				
					if FIFO32_M_Wr = '1' and FIFO32_S_Rd = '1' then
						--FIFO32_S_Data_out <= do;
						rdptr <= incptr(rdptr);
						we <= '1';
						di <= FIFO32_M_Data;
					end if;
					
					if FIFO32_M_Wr = '0' and FIFO32_S_Rd = '0' then
						sel_delay <= '1';
						state <= RAM_ACTIVE_DELAY;
					end if;
					
			end case;
		end if;
	end process;
	
	

end architecture;

