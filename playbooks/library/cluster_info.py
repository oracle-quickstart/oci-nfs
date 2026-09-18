#!/usr/bin/python
# 
# Description:
# Turns `crm configure show` and `crm_mon`output into 
# a json object that can be used in Ansible. i.E. to iterate over all
# nodes in a cluster, check for the location of a resource and so on.
#
# Dependencies:
# - xmltodict - https://pypi.org/project/xmltodict/
#
# Reference:

from ansible.module_utils.basic import AnsibleModule
import xmltodict


def empty_status():
    return {
        'nodes': {},
        'resources': {},
        'summary': {
            'nodes_configured': {'number': '0'},
            'stack': {'pacemakerd-state': 'not running'},
        },
    }


def as_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def map_status(status, key):
    mapped = {}
    for item in as_list(status):
        if isinstance(item, dict) and item.get(key):
            mapped[item[key]] = item
    return mapped


def crm_mon_parser(module):
    rc, output, err = module.run_command(['crm_mon', '--as-xml'])
    error_text = err.lower()

    # A fresh or stopped cluster returns 102 because crm_mon cannot connect.
    # This is a valid bootstrap state; unexpected crm_mon failures remain fatal.
    disconnected = rc == 102 and (
        'not connected' in error_text or 'connection refused' in error_text
    )
    if disconnected:
        return rc, empty_status(), err, False

    if rc != 0:
        module.fail_json(
            msg='crm_mon failed', rc=rc, stdout=output, stderr=err
        )

    try:
        dict_status = xmltodict.parse(output, attr_prefix='')
    except Exception as exc:
        module.fail_json(
            msg='Unable to parse crm_mon XML output',
            rc=rc,
            stdout=output,
            stderr=err,
            error=str(exc),
        )

    crm_mon = dict_status.get('crm_mon') or {}
    nodes = (crm_mon.get('nodes') or {}).get('node')
    resources = (crm_mon.get('resources') or {}).get('resource')
    summary = crm_mon.get('summary') or {}
    summary.setdefault('nodes_configured', {'number': '0'})
    summary.setdefault('stack', {'pacemakerd-state': 'unknown'})

    mapped_nodes = map_status(nodes, 'name')
    for node in mapped_nodes.values():
        if 'online' in node:
            node['online'] = str(node['online']).lower() == 'true'

    parsed_status = {
        'nodes': mapped_nodes,
        'resources': map_status(resources, 'resource_agent'),
        'summary': summary,
    }

    return rc, parsed_status, err, True


def run_module():
    result = dict(changed=False)
    module = AnsibleModule(argument_spec={}, supports_check_mode=True)

    if module.check_mode:
        result['connected'] = False
        result['status'] = empty_status()
        module.exit_json(**result)

    rc, status, err, connected = crm_mon_parser(module)
    result['connected'] = connected
    result['status'] = status
    result['rc'] = rc
    result['error'] = err
    module.exit_json(**result)


def main():
    run_module()


if __name__ == '__main__':
    main()
