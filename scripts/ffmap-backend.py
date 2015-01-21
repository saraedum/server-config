#!/usr/bin/env python3
'''
Convert data received from alfred to a format accepted by ffmap-d3.

Typical call::

    alfred -r 64 > maps.txt
    ./ffmap-backend.py -m maps.txt -a aliases.json > nodes.json

License: CC0 1.0
Author: Moritz Warning
Author: Julian Rueth (julian.rueth@fsfe.org)
'''

import sys
if sys.version_info[0] < 3:
    raise Exception("ffmap-backend.py must be executed with Python 3.")

from pprint import pprint, pformat

# list of firmware version that are not legacy.
RECENT_FIRMWARES = ["ffbi-0.4-rc.2", "server"]

class AlfredParser:
    r'''
    A class providing static methods to parse and validate data reported by
    nodes via alfred.

    >>> AlfredParser.parse_node(r'{ "ca:ff:ee:ca:ff:ee", "{\"community\": \"bielefeld\", \"name\":\"MyNode\"}" },')
    Node('ca:ff:ee:ca:ff:ee', {'clientcount': 0,
     'community': 'bielefeld',
     'firmware': None,
     'gateway': False,
     'geo': None,
     'name': 'MyNode',
     'vpn': False}, online=True)

    The data is mostly JSON. However, alfred wraps it in a strange format which
    requires some manual parsing.
    The validation of the JSON entries is done through a `JSON Schema
    <http://json-schema.org/>`_.
    '''
    MAC_RE = "^([0-9a-f]{2}:){5}[0-9a-f]{2}$"
    GEO_RE = "^\d{1,3}\.\d+ \d{1,3}\.\d+$"
    NAME_RE = "^[\-\^'\w\.\:\[\]\(\)\/ ]*$"
    MAC_SCHEMA = { "type": "string", "pattern": MAC_RE }
    ALFRED_NODE_SCHEMA = {
        "type": "object",
        "required": [ "community" ],
        "additionalProperties": False,
        "properties": {
            "geo": { "type": "string", "pattern": GEO_RE },
            "name": { "type": "string", "pattern": NAME_RE },
            "firmware": { "type": "string", "pattern": NAME_RE },
            "community": { "type": "string", "pattern": NAME_RE },
            "clientcount": { "type": "integer", "minimum": 0, "maximum": 255 },
            "gateway": { "type": "boolean" },
            "vpn": { "type": "boolean" },
            "links": {
                "type": "array",
                "items": { "$ref": "#/definitions/link" }
            }
        },
        "definitions": {
            "MAC": MAC_SCHEMA,
            "link": {
                "type": "object",
                "properties": {
                    "smac": { "$ref": "#/definitions/MAC" },
                    "dmac": { "$ref": "#/definitions/MAC" },
                    "qual": { "type": "integer", "minimum": 0, "maximum": 255 },
                    "type": { "enum": [ "vpn" ] },
                },
                "required": ["smac", "dmac"],
                "additionalProperties": False
            }
        } 
    }

    @staticmethod
    def _parse_string(s):
        r'''
        Strip an escaped string which is enclosed in double quotes and
        unescape. 

        >>> AlfredParser._parse_string(r'""')
        ''
        >>> AlfredParser._parse_string(r'"\""')
        '"'
        >>> AlfredParser._parse_string(r'"\"geo\""')
        '"geo"'
        '''
        if s[0] != '"' or s[-1] != '"':
            raise ValueError("malformatted string: {0:r}".format(s))
        return bytes(s[1:-1], 'ascii').decode('unicode-escape')

    @staticmethod
    def parse_node(item):
        r'''
        Parse and validate a line as returned by alfred.

        Such lines consist of a nodes MAC address and an escaped string of JSON
        encoded data. Note that most missing fields are populated with
        reasonable defaults.

        >>> AlfredParser.parse_node(r'{ "fa:d1:11:79:38:32", "{\"community\": \"bielefeld\"}" },')
        Node('fa:d1:11:79:38:32', {'clientcount': 0,
         'community': 'bielefeld',
         'firmware': None,
         'gateway': False,
         'geo': None,
         'name': 'fa:d1:11:79:38:32',
         'vpn': False}, online=True)

        >>> AlfredParser.parse_node(r'{ "fa:d1:11:79:38:32", "{\"community\": \"bielefeld\", \"invalid\": \"property\"}" },') # doctest: +ELLIPSIS
        Traceback (most recent call last):
        ...
        jsonschema.exceptions.ValidationError: Additional properties are not allowed ('invalid' was unexpected)
        ...

        .. todo::

            Does not supported GZIP compressed entries yet.

        '''
        import json, jsonschema
        #TODO: Handle gzipped entries

        # parse the strange output produced by alfred { MAC, JSON },
        if item[-2:] != "}," or item[0] != "{":
            raise ValueError("malformatted line: {0}".format(item))
        mac, properties = item[1:-2].split(',',1)

        # the first part must be a valid MAC
        mac = AlfredParser._parse_string(mac.strip())
        jsonschema.validate(mac, AlfredParser.MAC_SCHEMA)

        # the second part must conform to ALFRED_NODE_SCHEMA
        properties = AlfredParser._parse_string(properties.strip())
        properties = json.loads(properties)
        jsonschema.validate(properties, AlfredParser.ALFRED_NODE_SCHEMA)

        # set some defaults for unspecified fields
        properties.setdefault('name', mac)
        properties['geo'] = properties.get('geo','').split() or None
        properties.setdefault('firmware', None)
        properties.setdefault('clientcount', 0)
        properties.setdefault('gateway', False)
        properties.setdefault('vpn', False)
        properties.setdefault('links', [])
        links = properties['links']
        del properties['links']

        # create a Node and its Links from the data
        ret = Node(mac, properties, True)
        ret.update_links([Link(ret, link['smac'], link['dmac'], link.get('qual',1)) for link in links])
        return ret

class Node:
    r'''
    A node in the freifunk network, identified by its primary MAC.

    >>> Node('fa:d1:11:79:38:32', { 'community': 'bielefeld' }, online=True)
    Node('fa:d1:11:79:38:32', {'community': 'bielefeld'}, online=True)

    The second parameter is a dictionary of attributes (e.g. as reported
    through alfred.)
    Links can be added to a node through :meth:`update_links`.
    '''
    def __init__(self, mac, properties, online):
        self.mac = mac
        self.properties = properties
        self.links = []
        self.online = online

    def update_properties(self, properties):
        r'''
        Replace any properties with their respective values in ``properties``.

        >>> n = Node('fa:d1:11:79:38:32', { 'community': 'bielefeld' }, online=True)
        >>> n.update_properties({'community': 'ulm'})
        >>> n
        Node('fa:d1:11:79:38:32', {'community': 'ulm'}, online=True)

        '''
        self.properties.update(properties)

    def update_links(self, links):
        r'''
        Extend the list of links of this node with `links`.

        >>> node = Node('fa:d1:11:79:38:32', { 'community': 'bielefeld' }, online=True)
        >>> node.links
        []
        >>> node.update_links([Link(node, 'fa:d1:11:79:38:32', 'af:d1:11:79:38:32', .5)])
        >>> node.links
        [fa:d1:11:79:38:32 (of fa:d1:11:79:38:32) -> af:d1:11:79:38:32 (of ?)]

        '''
        self.links.extend(links)

    def ffmap(self):
        r'''
        Render this node (without its links) to a dictionary in a format
        understood by ffmap.

        >>> node = AlfredParser.parse_node(r'{ "fa:d1:11:79:38:32", "{\"community\":\"bielefeld\"}" },')
        >>> pprint(node.ffmap())
        {'clientcount': 0,
         'clients': [],
         'community': 'bielefeld',
         'firmware': None,
         'flags': {'gateway': False, 'legacy': True, 'online': True, 'vpn': False},
         'geo': None,
         'id': 'fa:d1:11:79:38:32',
         'name': 'fa:d1:11:79:38:32'}

        This method requires some properties to be set::

        >>> del(node.properties['geo'])
        >>> node.ffmap()
        Traceback (most recent call last):
        ...
        ValueError: node is missing required property 'geo'.

        '''
        properties = self.properties
        try:
            return {
                'id': self.mac,
                'name': properties['name'],
                'geo': properties['geo'],
                'community': properties['community'],
                'firmware': properties['firmware'],
                'clientcount': properties['clientcount'],
                'clients': [None]*properties['clientcount'],
                'flags': {
                    "legacy": properties['firmware'] not in RECENT_FIRMWARES,
                    "gateway": properties['gateway'],
                    "vpn": properties["vpn"],
                    "online": self.online
                }
            }
        except KeyError as e:
            raise ValueError("node is missing required property '{0}'.".format(e.args[0]))

    # a printable representation (which is missing the links)
    def __repr__(self): return r'Node({0!r}, {1!s}, online={2!r})'.format(self.mac, pformat(self.properties), self.online)

class Link:
    # TODO: docstring
    def __init__(self, source, smac, dmac, quality):
        self.source = source
        self.smac = smac
        self.dmac = dmac
        self.quality = quality
        self.reverse = None

    def json(self):
        # TODO: docstring
        # TODO: check reverse
        return { 
            'id': '{}-{}'.format(link.smac,link.dmac),
            'source': link.source.index,
            'target': link.reverse.source.index,
            'quality': '{:.3f}, {:.3f}'.format(255./max(1, link.quality), 255./max(1, link.quality)),
            'type': 'vpn' if link.source.properties['vpn'] or link.reverse.source.properties['vpn'] else None
        }

    # a printable representation
    def __repr__(self): return r'{0} (of {1}) -> {2} (of {3})'.format(self.smac, self.source.mac, self.dmac, self.reverse.mac if self.reverse else '?')

def render_ffmap(nodes):
    # TODO: docstring and comments
    ret = {}

    import datetime
    ret['meta'] = { 'timestamp': datetime.datetime.utcnow().replace(microsecond=0).isoformat() }

    ret['nodes'] = []
    for i, node in enumerate(nodes):
        node.index = i
        ret['nodes'].append(node.json())

    links = {}
    for node in nodes:
        for link in node.links:
            links[(link.smac, link.dmac)] = link

    ret['links'] = []
    for link in links.values():
        if link.reverse:
            continue

        try:
            reverse = links[(link.dmac, link.smac)]
        except KeyError:
            import traceback
            traceback.print_exc(0, sys.stderr)
            continue

        link.reverse = reverse
        link.reverse.reverse = link

        ret['links'].append(link.json())

    return ret

def main():
    # TODO: docstring and comments
    import argparse, sys, json
    parser = argparse.ArgumentParser('Convert data received from alfred to a format accepted by ffmap-d3')
    parser.add_argument('-a', '--aliases', type=argparse.FileType('r'))
    parser.add_argument('-m', '--maps', required=True, type=argparse.FileType('r'))
    parser.add_argument('-o', '--output', type=argparse.FileType('w'), default=sys.stdout)
    args = parser.parse_args()

    nodes = {}
    for line in args.maps.readlines():
        try:
            node = AlfredParser.parse_node(line.strip())
        except:
            import traceback
            traceback.print_exc()
            continue
        if node.mac in nodes:
            nodes[node.mac].update_properties(node.properties)
            nodes[node.mac].update_links(node.links)
        else:
            nodes[node.mac] = node

    if args.aliases:
        aliases = json.loads(args.aliases.read())
        for mac, properties in aliases.items():
            if mac in nodes:
                nodes[mac].update_properties(properties)

    args.output.write(json.dumps(render_ffmap(nodes.values())))

if __name__ == '__main__':
    main()
