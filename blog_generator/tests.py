import pytest
import os
from os.path import join, abspath, dirname
from blog_generator import Builder

def test_generate_files_structure_empty_blog():
    reference_folder = "testing_inputs/empty_blog"
    destination_folder = "output"
    blog_builder = Builder(reference_folder,destination_folder)
    blog_builder.build_blog()
    expected_paths = [
            destination_folder,
            join(destination_folder,"static"),
            join(destination_folder,"pages"),
            join(destination_folder,"posts")
            ]
    for path in expected_paths:
        assert(os.path.exists(path))

def test_generate_files_structure_blog_with_index_page():
    reference_folder = "testing_inputs/index_blog"
    destination_folder = "output"
    blog_builder = Builder(reference_folder,destination_folder)
    blog_builder.build_blog()
    expected_paths = [
            destination_folder,
            join(destination_folder,"static"),
            join(destination_folder,"pages"),
            join(destination_folder,"posts"),
            join(destination_folder,"index.html")
            ]
    for path in expected_paths:
        assert(os.path.exists(path))
