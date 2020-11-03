import os
from os.path import join, abspath, dirname
import jinja2
import markdown2
import logging
import importlib
import importlib.util
import sys
from shutil import copyfile
FORMAT = '%(asctime)-15s %(message)s'
logging.basicConfig(level=logging.DEBUG,format=FORMAT)
class Builder:
    def __init__(self, reference_folder, destination_folder):
        base = abspath(reference_folder)
        destination = abspath(destination_folder)
        self.folders = \
        {
                "base": base,
                "destination":  destination, 
                "templates":  join(base,"templates"),
                "static":     join(base,"static"),
                "content":    join(base,"content"),
                "posts":  join(base,"content","posts"),
                "pages":  join(base,"content","pages")
        }

        self.jinja_env = jinja2.Environment(loader=jinja2.FileSystemLoader(self.folders['templates']))
        self.files = {
                'global_conf':join(self.folders["base"],"conf.py"),
        }

        self.expected_folders = {
                "destination":destination,
                "static":join(destination,"static"),
                "pages":join(destination,"pages"),
                "posts":join(destination,"posts"),
                }

        self.templates_filepath= [join(self.folders['templates'],f)
                for f in os.listdir(self.folders['templates'])]
        self.templates = {}
        for f in os.listdir(self.folders['templates']):
            template = open(join(self.folders['templates'],f)).read()
            #print("*"*100)
            #print(template)
            self.templates[os.path.splitext(f)[0]] = self.jinja_env.from_string(template) 
            #print("*"*100)
        self.post_template = self.find_template(filename="post",type_="post")  
        
    def build_blog(self):
        for folder in self.expected_folders.values():
            if not os.path.exists(folder):
                os.mkdir(folder)
        for file_ in os.listdir(self.folders["static"]):
            copyfile(join(self.folders["static"],file_),join(self.expected_folders["static"],file_)) 
        self.scope, self.templates = self.build_scope_n_templates()
        self.rendered_templates = self.render_templates()

    def build_scope_n_templates(self):
        scope = {}
        templates = {"post":self.post_template}

        conf_spec = importlib.util.spec_from_file_location("conf", self.files['global_conf'])
        conf_module =  importlib.util.module_from_spec(conf_spec)
        conf_spec.loader.exec_module(conf_module)
        sys.modules["conf"] = conf_module
        d = conf_module.__dict__
        scope["global"] = {key: d[key] for key in d 
                                if "__" not in key}
        scope["pages"] = {}
        for page_relativepath in os.listdir(self.folders['pages']):
            page_filename, extension = os.path.splitext(page_relativepath)
            page_fullpath = join(self.folders['pages'], page_relativepath)
            page_template = self.find_template(page_filename, type_="page")
            variables, content = self.read_page_info(page_fullpath,
                                                    type_="page",
                                                    extension_=extension) 
            context  = scope["global"].copy()
            context.update(variables)
            content = markdown2.markdown(self.jinja_env.from_string("".join(content)).render(context))
            variables.update({"content":content})

            templates[page_filename] = page_template
            scope["pages"][page_filename] = variables


        scope["posts"] = {}
        for post_relativepath in os.listdir(self.folders['posts']):
            post_filename, extension = os.path.splitext(post_relativepath)
            post_fullpath = join(self.folders['posts'], post_relativepath)
            variables, content = self.read_page_info(post_fullpath,
                                                    type_="post",
                                                    extension_=extension) 
            context  = scope["global"].copy()
            context.update(variables)
            content = markdown2.markdown(self.jinja_env.from_string("".join(content)).render(context))
            variables.update({"content":content})
            scope["posts"][post_filename] = variables

        scope["ordered_posts"] = sorted([self.set_context(post_relativepath, scope, page_type="post",)
                                for post_relativepath in  os.listdir(self.folders['posts'])]
                              , key     = lambda dict_: dict_["date"]
                              , reverse = True
                             ) 

        scope["ordered_pages"] = sorted(
                [dict(d,**{"name":key}) for key,d in scope["pages"].items()],
                key= lambda d: d["navbar_position"]
                )
        return scope, templates

    def render_templates(self):
        print(os.listdir(self.folders['pages']))
        for page_relativepath in os.listdir(self.folders['pages']):
            page_context = self.set_context(page_relativepath, self.scope, page_type="page")
            p_ctx = page_context
            p_ctx['posts_list'] = self.scope["ordered_posts"]
            p_ctx['pages_list'] = self.scope["ordered_pages"]
            with open(p_ctx['destination_fullpath'],"w") as outf:
                outf.write( p_ctx["template"].render(p_ctx) )

        for post_context in self.scope["ordered_posts"]:
            p_ctx = post_context
            p_ctx['posts_list'] = self.scope["ordered_posts"]
            p_ctx['pages_list'] = self.scope["ordered_pages"]
            with open(p_ctx['destination_fullpath'],"w") as outf:
                outf.write( p_ctx['template'].render(p_ctx) )

    def set_context(self, relativepath, scope, page_type):
            pageType_folder = f'{page_type}s'
            filename, extension = os.path.splitext(relativepath)
            fullpath = join(self.folders[pageType_folder], relativepath)

            if filename == "index":
                destination_filepath = join(self.expected_folders['destination'],f'{filename}.html')
            else:
                destination_filepath = join(self.expected_folders[pageType_folder],f'{filename}.html')


            context = scope["global"].copy()

            if page_type == "post":
                context.update({"template":self.templates["post"]})
            else:
                context.update({"template":self.templates[filename]})

            context.update(scope[pageType_folder][filename])
            context.update({"pages":scope["pages"]})
            context.update({"posts":scope["posts"]})
            context.update({"template_name":filename})
            context.update({"templates":self.templates})
            context.update({"destination_fullpath": destination_filepath})

            logging.debug(destination_filepath)
            return context

    def find_template(self,filename,type_):
        found = False
        matched_templates = [fp for fp in self.templates_filepath if filename in fp.split("/")[-1]]
        if matched_templates:
            template_filepath = matched_templates[0] 
            return self.jinja_env.from_string(open(template_filepath).read())
 
        else:
            raise Exception("Could not find template")

    def read_page_info(self, page_fullpath, type_, extension_):
        variables = {}
        contents = []
        print("*"*100)
        print(open(page_fullpath).read())
        with open(page_fullpath) as inpf:
            try: 
                next_line = inpf.__next__().strip()
                while next_line:
                    print(next_line)
                    variable_name, *value = next_line.split(":")
                    value = ":".join(value).strip()
                    variables[variable_name.lower()] = value.strip()
                    next_line = inpf.__next__().strip()
            except:
                print("*"*100)
                for content in inpf:
                    contents.append(content)
            else:
                print("*"*100)
                for content in inpf:
                    contents.append(content)
        if variables.get("date",False):
            d = variables["date"]
            year, month, day = d.split(" ")[0].split("-")
            month_name = {
                    1:"january",
                    2:"february",
                    3:"march",
                    4:"april",
                    5:"may",
                    6:"june",
                    7:"july",
                    8:"august",
                    9:"september",
                    10:"october",
                    11:"november",
                    12:"december"
                    }[int(month)]
            variables["formatted_date"] = f'{year} {int(day)}th of {month_name}'
        return variables, contents                
