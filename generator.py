#!/bin/python3

import yaml
import json
import re

file_list = [
    'zsh/fun.sh',
    'zsh/alias.sh',
        ]

manual_dic = {}

def ReadHead(file_path: str):
    with open(file_path, 'r') as f:
        yaml_str = ''
        manual_dic[file_path] = []
        is_new = True

        while True:
            line = f.readline()
            if line == '':
                break
            if re.search('---',line):
                if is_new:
                    is_new = False
                    continue

                print(yaml_str)
                tmp_dic = yaml.load(yaml_str, Loader=yaml.BaseLoader)
                manual_dic[file_path].append(tmp_dic)
                yaml_str = ''
                is_new = True

            if not is_new:
                yaml_str += line[1:]


def manaul_scan():
    for file_item in file_list:
        ReadHead(file_item)


def print_json():
    with open('doc/manaul.json', 'w') as f:
        json.dump(manual_dic, f, indent=4, separators=(',', ':'))

def print_md():
    with open('doc/manaul.md', 'w') as f:
        f.write('# manual\n\n')
        for key, value in manual_dic.items():
            f.write('## ' + key + '\n\n')
            f.write('| key | note | code | pic |\n')
            f.write('| --- | ---- | ---- | --- |\n')
            for item in value:
                f.write(
                        '| ' + \
                        item['key'] + ' | ' + \
                        item['note'] + ' | ' + \
                        item['code'] + ' | '
                        )

                if item['pic'] != '':
                    f.write('![pic](' + item['pic'] + ')')
                f.write(' |\n')

            f.write('\n')


if __name__ == '__main__':
    manaul_scan()
    print_json()
    print_md()
    # print(manual_dic)
