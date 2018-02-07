------------------------------------------------------------------------------
-- @name: VGA Display Module 800 * 600 @75Hz (Clock: 50MHz)
-- @description: (1st) Fetch data from SDRAM using Qsys SDRAM IP in certain address,
--               and then cast them on the screen through VGA Display Module
--               that we write.
--               (2nd) Em... We decided not to use Qsys... 
------------------------------------------------------------------------------
-- The standard we are using: 
-- Clock frequencies   : 50MHz
-- Horizontal timing information
--    sync pulse       : 128
--    back porch       : 88
--    active           : 800
--    front porch      : 40
--    all lines        : 1056
-- Vertical timing information
--    sync pulse       : 4
--    back porch       : 23
--    active           : 600
--    front porch      : 1
--    all lines        : 628
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity vga_init is
   port (
      clk          : in std_logic;
      rst          : in std_logic; -- low level trigger

      rgb_data     : in std_logic_vector(7 downto 0);

      vga_rgb      : out std_logic_vector (7 downto 0); -- R2, R1, R0, G2, G1, G0, B1, B0
		vga_vsync    : out std_logic;
      vga_hsync    : out std_logic

      -- vga_ready    : buffer std_logic  -- edge trigger to display VGA data
   );
end entity;

architecture behave of vga_init is

   --component ip_ram is
   --   port (
   --      address  : in std_logic_vector (4 downto 0);
   --      clock    : in std_logic;
   --      data     : in std_logic_vector (7 downto 0);
   --      rden     : in std_logic;
   --      wren     : in std_logic;

   --      q        : out std_logic_vector (7 downto 0)
   --   );
   --end component;

   type vga_state is (zero_state, sync_pulse_state, back_porch_state, active_state, front_porch_state);
   type reset_state is (reset_active, reset_negative);
   shared variable vga_hsync_state      : vga_state;
   shared variable vga_vsync_state      : vga_state;
   shared variable reset_sync_state     : reset_state;
   shared variable vga_hsync_cnt        : integer range 0 to 800;
   shared variable vga_vsync_cnt        : integer range 0 to 600;

   constant H_SYNC_PULSE_MAX   : integer := 128;
   constant H_BACK_PORCH_MAX   : integer := 88;
   constant H_ACTIVE_MAX       : integer := 800;
   constant H_FRONT_PORCH_MAX  : integer := 40;

   constant V_SYNC_PULSE_MAX   : integer := 4;
   constant V_BACK_PORCH_MAX   : integer := 23;
   constant V_ACTIVE_MAX       : integer := 600;
   constant V_FRONT_PORCH_MAX  : integer := 1;

   --signal ram_address      : std_logic_vector (4 downto 0);
   --signal ram_data         : std_logic_vector (7 downto 0);
   --signal ram_rden         : std_logic;
   --signal ram_wren         : std_logic;
   --signal ram_q            : std_logic_vector (7 downto 0);

   procedure increase_one(cnt: inout integer) is
   begin
	   cnt := cnt + 1;
   end procedure;

   procedure clear_count(cnt: inout integer) is
   begin
      cnt := 0;
   end procedure;

   -- simulate a chain table
   procedure next_state(sync_state: inout vga_state) is
   begin
      case(sync_state) is
         when zero_state => sync_state := sync_pulse_state;
         when sync_pulse_state => sync_state := back_porch_state;
         when back_porch_state => sync_state := active_state;
         when active_state => sync_state := front_porch_state;
         when front_porch_state => sync_state := zero_state;
         when others =>
            null;
      end case;
	end procedure;
begin

-- instance of ip_ram --
--ip_ram_inst: ip_ram port map(
--   ram_address,
--   clk,
--   ram_data,
--   ram_rden,
--   ram_wren,
--   ram_q
--);

-- Reset --
reset: process(clk, rst)
begin
   if rst = '1' then
      reset_sync_state := reset_active;
   else
      reset_sync_state := reset_negative;
   end if;
end process;

-- If only I could use a chain table!
sync_state_manager: process(clk)
begin
	if clk'event and clk = '1' then
      if reset_sync_state = reset_active then
         vga_hsync_state := zero_state;
         vga_vsync_state := zero_state;
         --
         -- reset_display();
      else
   		-- Horizontal
   		case(vga_hsync_state) is

   			-- state_0
   			when zero_state =>
   				clear_count(vga_hsync_cnt);
   				next_state(vga_hsync_state);
   				vga_hsync <= '0';

   			-- state_1
   			when sync_pulse_state =>
   				if vga_hsync_cnt = H_SYNC_PULSE_MAX then
   					clear_count(vga_hsync_cnt);
   					next_state(vga_hsync_state);
   					-- vga_hsync <= '1';
   				else null;
   				end if;

   			-- state_2
   			when back_porch_state =>
   				if vga_hsync_cnt = H_BACK_PORCH_MAX then
   					clear_count(vga_hsync_cnt);
   					next_state(vga_hsync_state);
   				elsif vga_hsync_cnt = 1 then
   					-- line 149
   					vga_hsync <= '1';
   				else null;
   				end if;

   			-- state_3
   			when active_state =>
   				if vga_hsync_cnt = H_ACTIVE_MAX then
   					clear_count(vga_hsync_cnt);
   					next_state(vga_hsync_state);
   				elsif vga_vsync_state = active_state then
   					
   					-- display rgb image
   					vga_rgb <= rgb_data;
   				end if;

   			-- state_4
   			when front_porch_state =>
   				if vga_hsync_cnt = H_FRONT_PORCH_MAX then
   					clear_count(vga_hsync_cnt);
   					next_state(vga_hsync_state);

   					-- while a horizontal count turn ends, vertical count adds one.
   					increase_one(vga_vsync_cnt);
   				else null;
   				end if;

   			when others =>
   				null;
   		end case;
   		increase_one(vga_hsync_cnt);

   		-- Vertical
   		-- FIXME: should it be another process?
   		case(vga_vsync_state) is
   			when zero_state =>
   				clear_count(vga_vsync_cnt);
   				next_state(vga_vsync_state);
   				vga_vsync <= '0';
   			when sync_pulse_state =>
   				if vga_vsync_cnt = V_SYNC_PULSE_MAX then
   					clear_count(vga_vsync_cnt);
   					next_state(vga_vsync_state);
   				else null;
   				end if;
   			when back_porch_state =>
   				if vga_vsync_cnt = V_BACK_PORCH_MAX then
   					clear_count(vga_vsync_cnt);
   					next_state(vga_vsync_state);
   				elsif vga_vsync_cnt = 1 then
   					vga_vsync <= '1';
   				else null;
   				end if;
   			when active_state =>
   				if vga_vsync_cnt = V_ACTIVE_MAX then
   					clear_count(vga_vsync_cnt);
   					next_state(vga_vsync_state);
   				else null;
   				end if;
   			when front_porch_state =>
   				if vga_vsync_cnt = V_FRONT_PORCH_MAX then
   					clear_count(vga_vsync_cnt);
   					next_state(vga_vsync_state);
   				else null;
   				end if;
   			when others =>
   				null;
   		end case;

   	end if;
   end if;
end process;



-- Get data from RAM and show on the screen --
--ram_data: process(clk)
--begin
--
--end process;


end architecture;