#__author: liuchunming
#date: 2020/06/02

# coding:utf8  

import os
import sys

print("__file__")
print(__file__)
print("sys.argv[0]")
print(sys.argv[0])
print("os.path.dirname(__file__)")
print(os.path.dirname(__file__))
print("os.path.split(__file__)")
print(os.path.split(__file__))
print("os.path.split(__file__)[-1]")
print(os.path.split(__file__)[-1])
print(os.path.split(__file__)[-1].split(".")[0])