#!/usr/bin/env python

from sympy import symbols, Eq, solve

def parse_coeff(line):
    parts = line.split(' @ ')
    pt = parts[0].split(', ')
    vel = parts[1].split(', ')
    return (int(pt[0]), int(pt[1]), int(pt[2]), int(vel[0]), int(vel[1]), int(vel[2]))

def read_coeffs():
    with open('data.txt') as f:
        return (parse_coeff(f.readline()), parse_coeff(f.readline()), parse_coeff(f.readline()))

(X1, Y1, Z1, VX1, VY1, VZ1), (X2, Y2, Z2, VX2, VY2, VZ2), (X3, Y3, Z3, VX3, VY3, VZ3) = read_coeffs()

t1, t2, t3, x, y, z, vx, vy, vz = symbols('t1 t2 t3 x y z vx vy vz')

eq1 = Eq(X1 + VX1 * t1, x + t1 * vx)
eq2 = Eq(Y1 + VY1 * t1, y + t1 * vy)
eq3 = Eq(Z1 + VZ1 * t1, z + t1 * vz)
eq4 = Eq(X2 + VX2 * t2, x + t2 * vx)
eq5 = Eq(Y2 + VY2 * t2, y + t2 * vy)
eq6 = Eq(Z2 + VZ2 * t2, z + t2 * vz)
eq7 = Eq(X3 + VX3 * t3, x + t3 * vx)
eq8 = Eq(Y3 + VY3 * t3, y + t3 * vy)
eq9 = Eq(Z3 + VZ3 * t3, z + t3 * vz)

solution = solve((eq1, eq2, eq3, eq4, eq5, eq6, eq7, eq8, eq9), (x, y, z, t1, t2, t3, vx, vy, vz))[0]
(sx, sy, sz, *_) = solution

print(sx+sy+sz)
