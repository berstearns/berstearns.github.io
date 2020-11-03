from bloggen import Builder
import sys
import os
from os.path import join, abspath, dirname

blog_builder = Builder("blog_generator/inputs",".")
blog_builder.build_blog()
