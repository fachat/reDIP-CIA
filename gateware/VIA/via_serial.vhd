-- ----------------------------------------------------------------------------
-- This file is part of reDIP CIA, a MOS PIA/VIA/CIA FPGA emulation platform.
-- Copyright (C) 2025 - 2026  Dag Lem <resid@nimrod.no>
--
-- This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
--
-- You may redistribute and modify this source and make products using it under
-- the terms of the CERN-OHL-S v2 (https://ohwr.org/cern_ohl_s_v2.txt).
--
-- This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY,
-- INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A
-- PARTICULAR PURPOSE. Please see the CERN-OHL-S v2 for applicable conditions.
--
-- Source location: https://github.com/daglem/reDIP-CIA
-- ----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity via_serial is
    port (
        clk      : in  std_logic;
        phi2     : in  std_logic;
        rd       : in  std_logic;
        we       : in  std_logic;
        addr     : in  std_logic_vector(3 downto 0);
        data     : in  std_logic_vector(7 downto 0);
        acr      : in  std_logic_vector(7 downto 0);
        ifr      : in  std_logic_vector(7 downto 0);
        t2l_ufl  : in  std_logic;
        scli_cb1 : in  std_logic;
        si_cb2   : in  std_logic;
        sflag_o  : out std_logic_vector(1 downto 0);
        sr       : out std_logic_vector(7 downto 0) := (others => '1');
        sclo_cb1 : out std_logic;
        so_cb2   : out std_logic
    );
end entity via_serial;

architecture rtl of via_serial is
    signal asel_sr       : std_logic;
    signal sr_run        : std_logic;
    signal sr_in         : std_logic;
    signal sr_shift      : std_logic;
    signal sr_done       : std_logic;
    signal sclk_reg      : std_logic;
    signal sclk_prev     : std_logic;
    signal sclk_edge     : std_logic;
    signal sclk_toggle   : std_logic;
    signal sclk_latch    : std_logic;
    signal sclk_next     : std_logic;
    signal sr_latch      : std_logic_vector(7 downto 0);
    signal sr_cnt        : std_logic_vector(4 downto 0);
    signal sr_cnt_latch  : std_logic_vector(4 downto 0);
begin
    asel_sr <= '1' when addr = "1010" else '0';
    sr_in <= so_cb2 when acr(4) = '1' else si_cb2;
    sclk_next <= sclk_latch or not sr_run;
    sclk_edge <= (sclk_prev and not sclk_reg) when acr(4) = '1'
                 else (not sclk_prev and sclk_reg);

    process (sr_done, acr, sclo_cb1, rd, we, asel_sr)
    begin
        sflag_o(1) <= '0';
        if sr_done = '1' and acr(4 downto 2) /= "100"
           and (acr(3 downto 2) = "11" or sclo_cb1 = '1') then
            sflag_o(1) <= '1';
        end if;
        sflag_o(0) <= (rd or we) and asel_sr;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            if we = '1' and asel_sr = '1' then
                sr_latch <= data;
            elsif phi2 = '0' then
                if sr_shift = '1' then
                    so_cb2 <= sr(0);
                    sr_latch <= sr(7 downto 1) & sr_in;
                else
                    so_cb2 <= so_cb2;
                    sr_latch <= sr;
                end if;
            end if;

            if phi2 = '1' then
                sr_shift <= sclk_edge and not ifr(2);
                sr <= sr_latch;
            end if;

            if (rd = '1' or we = '1') and asel_sr = '1' then
                sr_run <= '1';
            elsif acr(4 downto 2) = "000" or ifr(2) = '1' then
                sr_run <= '0';
            end if;

            if phi2 = '1' then
                if ((acr(4 downto 2) = "100" or acr(3 downto 2) = "01")
                    and t2l_ufl = '1')
                   or acr(3 downto 2) = "10" then
                    sclk_toggle <= not ifr(2);
                else
                    sclk_toggle <= '0';
                end if;
            end if;

            if phi2 = '1' then
                sclk_latch <= sclk_next;
                sclo_cb1 <= sclk_next;
            elsif sclk_toggle = '1' then
                sclk_latch <= not sclo_cb1;
            end if;

            if sr_run = '0' then
                sr_cnt_latch <= (others => '1');
            elsif not (we = '1' and asel_sr = '1') and phi2 = '0' then
                if sr_shift = '1' then
                    sr_cnt_latch <= (not sr_cnt(0)) & sr_cnt(4 downto 1);
                else
                    sr_cnt_latch <= sr_cnt;
                end if;
            end if;

            if phi2 = '1' then
                sr_cnt <= sr_cnt_latch;
                sr_done <= sr_cnt_latch(2) and not sr_cnt_latch(1);
            end if;

            if phi2 = '1' then
                sclk_reg <= scli_cb1;
            end if;
            if phi2 = '0' then
                sclk_prev <= sclk_reg;
            end if;
        end if;
    end process;
end architecture rtl;
