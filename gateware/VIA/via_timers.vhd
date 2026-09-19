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
use ieee.numeric_std.all;

entity via_timers is
    port (
        clk              : in  std_logic;
        res              : in  std_logic;
        phi2             : in  std_logic;
        rd               : in  std_logic;
        we               : in  std_logic;
        addr             : in  std_logic_vector(3 downto 0);
        data             : in  std_logic_vector(7 downto 0);
        acr              : in  std_logic_vector(7 downto 0);
        t2_pb6           : in  std_logic;
        regs_t1_lo       : out std_logic_vector(7 downto 0);
        regs_t1_hi       : out std_logic_vector(7 downto 0);
        regs_t1_latch_lo : out std_logic_vector(7 downto 0);
        regs_t1_latch_hi : out std_logic_vector(7 downto 0);
        regs_t2_lo       : out std_logic_vector(7 downto 0);
        regs_t2_hi       : out std_logic_vector(7 downto 0);
        tflag_s_t1       : out std_logic;
        tflag_s_t2       : out std_logic;
        tflag_r_t1       : out std_logic;
        tflag_r_t2       : out std_logic;
        t1_pb7           : out std_logic;
        t2l_ufl          : out std_logic
    );
end entity via_timers;

architecture rtl of via_timers is
    constant ADDR_T1C_L : std_logic_vector(3 downto 0) := x"4";
    constant ADDR_T1C_H : std_logic_vector(3 downto 0) := x"5";
    constant ADDR_T1L_L : std_logic_vector(3 downto 0) := x"6";
    constant ADDR_T1L_H : std_logic_vector(3 downto 0) := x"7";
    constant ADDR_T2C_L : std_logic_vector(3 downto 0) := x"8";
    constant ADDR_T2C_H : std_logic_vector(3 downto 0) := x"9";

    signal w_t1c_h      : std_logic := '0';
    signal w_t1l_h      : std_logic := '0';
    signal t1_load      : std_logic := '0';
    signal t1_ufl       : std_logic := '0';
    signal t1_ufl_prev  : std_logic := '0';
    signal t1_run       : std_logic := '0';
    signal t1_pb7_prev  : std_logic := '0';
    signal s_t1         : std_logic := '0';
    signal s_t1_prev    : std_logic := '0';

    signal t1_latch      : std_logic_vector(15 downto 0) := (others => '1');
    signal t1_count      : std_logic_vector(15 downto 0) := (others => '1');
    signal t1_count_prev : std_logic_vector(15 downto 0) := (others => '0');
    signal t1_pb7_reg    : std_logic := '0';

    signal w_t2c_h      : std_logic := '0';
    signal t2_cin       : std_logic := '0';
    signal t2l_load     : std_logic := '0';
    signal t2l_ufl_prev : std_logic := '0';
    signal t2h_ufl      : std_logic := '0';
    signal t2_run       : std_logic := '0';
    signal t2_pb6_reg   : std_logic := '0';
    signal t2_pb6_last  : std_logic := '0';
    signal t2_pb6_prev  : std_logic := '0';
    signal s_t2         : std_logic := '0';
    signal s_t2_prev    : std_logic := '0';

    signal t2l_latch     : std_logic_vector(7 downto 0)  := (others => '1');
    signal t2_count      : std_logic_vector(15 downto 0) := (others => '1');
    signal t2_count_prev : std_logic_vector(15 downto 0) := (others => '0');
    signal t2_count_next : std_logic_vector(15 downto 0) := (others => '0');
    signal t2l_ufl_reg   : std_logic := '0';
begin
    w_t1c_h <= '1' when we = '1' and addr = ADDR_T1C_H else '0';
    w_t1l_h <= '1' when we = '1' and addr = ADDR_T1L_H else '0';
    t1_load <= '1' when t1_ufl_prev = '1' or w_t1c_h = '1' else '0';

    w_t2c_h <= '1' when we = '1' and addr = ADDR_T2C_H else '0';
    t2l_load <= '1' when (t2l_ufl_prev = '1' and (acr(4 downto 2) = "100" or acr(3 downto 2) = "01")) or w_t2c_h = '1' else '0';
    t2_count_next <= std_logic_vector(unsigned(t2_count_prev) - 1) when t2_cin = '1' else t2_count_prev;

    process (clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                case addr is
                    when ADDR_T1C_L | ADDR_T1L_L =>
                        t1_latch(7 downto 0) <= data;
                    when ADDR_T1C_H | ADDR_T1L_H =>
                        t1_latch(15 downto 8) <= data;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            if we = '1' and addr = ADDR_T2C_L then
                t2l_latch <= data;
            end if;
        end if;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            if phi2 = '0' then
                if t1_load = '1' then
                    t1_count <= t1_latch;
                else
                    t1_count <= std_logic_vector(unsigned(t1_count_prev) - 1);
                end if;

                if t1_count_prev = x"0000" and w_t1c_h = '0' then
                    t1_ufl <= '1';
                else
                    t1_ufl <= '0';
                end if;
            end if;

            if phi2 = '1' then
                t1_count_prev <= t1_count;
                t1_ufl_prev   <= t1_ufl;
            end if;
        end if;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            if phi2 = '0' then
                t2_pb6_reg  <= t2_pb6;
                t2_pb6_prev <= t2_pb6_last;
            end if;

            if phi2 = '1' then
                t2_pb6_last <= t2_pb6_reg;
            end if;

            if phi2 = '0' then
                if t2l_load = '1' then
                    t2_count(7 downto 0) <= t2l_latch;
                else
                    t2_count(7 downto 0) <= t2_count_next(7 downto 0);
                end if;

                if w_t2c_h = '1' then
                    t2_count(15 downto 8) <= data;
                else
                    t2_count(15 downto 8) <= t2_count_next(15 downto 8);
                end if;

                if t2_count_prev = x"0000" and t2_cin = '1' and w_t2c_h = '0' then
                    t2h_ufl <= '1';
                else
                    t2h_ufl <= '0';
                end if;

                if t2_count_prev(7 downto 0) = x"00" and t2_cin = '1' and t2l_load = '0' then
                    t2l_ufl_reg <= '1';
                else
                    t2l_ufl_reg <= '0';
                end if;
            end if;

            if phi2 = '1' then
                if acr(5) = '0' or (t2_pb6_prev = '1' and t2_pb6_last = '0') then
                    t2_cin <= '1';
                else
                    t2_cin <= '0';
                end if;

                t2_count_prev <= t2_count;
                t2l_ufl_prev  <= t2l_ufl_reg;
            end if;
        end if;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            if w_t1c_h = '1' then
                t1_run <= '1';
            elsif res = '1' or (s_t1_prev = '1' and acr(6) = '0') then
                t1_run <= '0';
            end if;

            if phi2 = '1' then
                if t1_run = '1' and t1_ufl = '1' then
                    s_t1 <= '1';
                else
                    s_t1 <= '0';
                end if;
            end if;

            if phi2 = '0' then
                s_t1_prev   <= s_t1;
                t1_pb7_prev <= t1_pb7_reg;
            end if;

            if w_t1c_h = '1' then
                t1_pb7_reg <= '0';
            elsif acr(7) = '0' then
                t1_pb7_reg <= '1';
            elsif phi2 = '1' and t1_run = '1' and t1_ufl = '1' then
                t1_pb7_reg <= not t1_pb7_prev;
            end if;
        end if;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            if w_t2c_h = '1' then
                t2_run <= '1';
            elsif res = '1' or s_t2_prev = '1' then
                t2_run <= '0';
            end if;

            if phi2 = '1' then
                if t2_run = '1' and t2h_ufl = '1' then
                    s_t2 <= '1';
                else
                    s_t2 <= '0';
                end if;
            end if;

            if phi2 = '0' then
                s_t2_prev <= s_t2;
            end if;
        end if;
    end process;

    tflag_s_t1 <= s_t1;
    tflag_r_t1 <= '1' when (rd = '1' and addr = ADDR_T1C_L) or w_t1c_h = '1' or w_t1l_h = '1' else '0';

    tflag_s_t2 <= s_t2;
    tflag_r_t2 <= '1' when (rd = '1' and addr = ADDR_T2C_L) or w_t2c_h = '1' else '0';
    t1_pb7     <= t1_pb7_reg;
    t2l_ufl    <= t2l_ufl_reg;

    regs_t1_hi       <= t1_count(15 downto 8);
    regs_t1_lo       <= t1_count(7 downto 0);
    regs_t1_latch_hi <= t1_latch(15 downto 8);
    regs_t1_latch_lo <= t1_latch(7 downto 0);
    regs_t2_hi       <= t2_count(15 downto 8);
    regs_t2_lo       <= t2_count(7 downto 0);
end architecture rtl;
