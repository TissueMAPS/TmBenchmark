#!/usr/bin/env python
import os
import re
import json
import collections
from datetime import datetime
try:
    from cStringIO import StringIO
except ImportError:
    from io import StringIO

import requests
import pandas as pd
import numpy as np


WORKFLOW_STEPS = [
    'metaextract', 'metaconfig', 'imextract',
    'corilla', 'illuminati', 'jterator'
]


RAW_METRICS = {
    'bytes_out': {
        'uri': 'm=bytes_out&vl=bytes%2Fsec&ti=Bytes%20Sent',
        'unit': 'bytes per second',
        'name': 'send data',
    },
    'bytes_in': {
        'uri': 'm=bytes_in&vl=bytes%2Fsec&ti=Bytes%20Received',
        'unit': 'bytes per second',
        'name': 'received data',
    },
    'mem_free': {
        'uri': 'm=mem_free&vl=KB&ti=Free%20Memory',
        'unit': 'kilobytes',
        'name': 'free memory'
    },
    'mem_total': {
        'uri': 'm=mem_total&vl=KB&ti=Total%20Memory',
        'unit': 'kilobytes',
        'name': 'total memory'
    },
    'cpu_user': {
        'uri': 'm=cpu_user&vl=%25&ti=CPU%20User',
        'unit': 'percent',
        'name': 'CPU user'
    },
    'cpu_system': {
        'uri': 'm=cpu_system&vl=%25&ti=CPU%20System',
        'unit': 'percent',
        'name': 'CPU system'
    },
    'cpu_num': {
        'uri': 'm=cpu_num&vl=%25&ti=CPU%20Number',
        'unit': '',
        'name': 'number of processors'
    },
    'load_one': {
        'uri': 'm=load_one&vl=%20&ti=One%20Minute%20Load%20Average',
        'unit': '',
        'name': 'one minute load average'
    }
}

FORMATTED_METRICS = {
    'memory': {
        'func': lambda m: (m['mem_total'] - m['mem_free']) / float(m['mem_total']) * 100,
        'unit': 'percent',
        'name': 'memory usage'
    },
    'cpu': {
        'func': lambda m: m['cpu_user'] + m['cpu_system'],
        'unit': 'percent',
        'name': 'CPU usage'
    },
    'input': {
        'func': lambda m: m['bytes_in'],
        'unit': 'bytes per second',
        'name': 'data input'
    },
    'output': {
        'func': lambda m: m['bytes_out'],
        'unit': 'bytes per second',
        'name': 'data output'
    }
}


def _get_number_of_processors(cluster):
    match = re.search(r'^cluster-([0-9]+)$', cluster)
    n = match.group(1)
    # All cluster architectuers use nodes with 4 processors
    return int(n)/4


def _get_compute_nodes(cluster):
    n = _get_number_of_processors(cluster)
    return tuple([
        '{0}-slurm-worker-{1:03d}'.format(cluster, i+1) for i in range(n)
    ])


def _get_fs_nodes(cluster):
    n = _get_number_of_processors(cluster)
    # Ratio of compute to storage nodes is 1:4
    return tuple([
        '{0}-glusterfs-server-{1:03d}'.format(cluster, i+1)
        for i in range(n/4)
    ])


def _get_db_coordinator_nodes(cluster):
    return tuple(['{0}-postgresql-master-001'.format(cluster)])


def _get_db_worker_nodes(cluster):
    n = _get_number_of_processors(cluster)
    # Ratio of compute to storage nodes is 1:4
    return tuple([
        '{0}-postgresql-worker-{1:03d}'.format(cluster, i+1)
        for i in range(n/4)
    ])


HOST_GROUPS = {
    'compute': {
        'name': 'compute',
        'hosts': lambda cluster: _get_compute_nodes(cluster)
    },
    'fs': {
        'name': 'filesystem',
        'hosts': lambda cluster: _get_fs_nodes(cluster)
    },
    'db_coordinator': {
        'name': 'database coordinator',
        'hosts': lambda cluster: _get_db_coordinator_nodes(cluster)
    },
    'db_worker': {
        'name': 'database worker',
        'hosts': lambda cluster: _get_db_worker_nodes(cluster)
    }
}


def download_raw_metrics(host, cluster, workflow_statistics):
    base_uri = 'http://{address}/ganglia/graph.php?r=4hr&c={cluster}'.format(
        address=host, cluster=cluster
    )
    ganglia_dt_format = '%m%%2F%d%%2F%Y+%H%%3A%M'
    workflow_dt_format = '%Y-%m-%d %H:%M:%S'
    data = dict()
    for i, step in enumerate(WORKFLOW_STEPS):

        current_index = np.where(
            workflow_statistics['name'] == step
        )[0][0]
        current_step_stats = workflow_statistics.loc[current_index, :]
        if i > 0:
            prior_step_index = np.where(
                workflow_statistics['name'] == WORKFLOW_STEPS[i-1]
            )[0][0]
            prior_step_stats = workflow_statistics.loc[prior_step_index, :]
            start = prior_step_stats['updated_at'].split('.')[0]
        else:
            first_task_index = np.where(
                workflow_statistics['name'] == '{}_init'.format(step)
            )[0][0]
            first_task_stats = workflow_statistics.loc[first_task_index, :]
            start = first_task_stats['updated_at'].split('.')[0]
        start = datetime.strptime(start, workflow_dt_format)
        end = current_step_stats['updated_at'].split('.')[0]
        end = datetime.strptime(end, workflow_dt_format)
        start_uri = 'cs={}'.format(start.strftime(ganglia_dt_format))
        end_uri = 'ce={}'.format(end.strftime(ganglia_dt_format))

        data[step] = dict()
        for group in HOST_GROUPS:
            data[step][group] = dict()
            for metric in RAW_METRICS:
                metric_uri = RAW_METRICS[metric]['uri']
                tmp_data = list()
                for node in HOST_GROUPS[group]['hosts'](cluster):
                    node_uri = 'h={}'.format(node)
                    url = '&'.join([
                        base_uri, node_uri, start_uri, end_uri, metric_uri,
                        'csv=1'
                    ])
                    response = requests.get(url)
                    f = StringIO(response.content)
                    stats = pd.read_csv(f, header=0, index_col=0, names=[node])
                    tmp_data.append(stats[node])
                data[step][group][metric] = pd.concat(tmp_data, axis=1)
    return data


def format_raw_metrics(data, workflow_statistics):
    formatted_data = dict()
    for step in WORKFLOW_STEPS:
        formatted_data[step] = pd.DataFrame(
            index=HOST_GROUPS.keys(), columns=FORMATTED_METRICS.keys()
        )
        for group in HOST_GROUPS:
            aggregates = dict()
            for metric in RAW_METRICS:
                measurements = data[step][group][metric]
                # TODO: cutoff?
                # Some steps may not execute jobs on all nodes, which may
                # introduce a bias upon summary statistics.
                values = measurements[measurements > 0].values
                aggregates[metric] = np.nanmean(values)
            for metric in FORMATTED_METRICS:
                func = FORMATTED_METRICS[metric]['func']
                formatted_data[step].loc[group, metric] = func(aggregates)
    return formatted_data


def safe_formatted_metrics(data, directory):
    for step in WORKFLOW_STEPS:
        for metric in FORMATTED_METRICS:
            subdirectory = os.path.join(directory, step)
            if not os.path.exists(subdirectory):
                os.makedirs(subdirectory)
            filepath = os.path.join(subdirectory, 'metrics.csv')
            with open(filepath, 'w') as f:
                data[step].to_csv(f)


def load_raw_metrics(directory):
    data = dict()
    for step in WORKFLOW_STEPS:
        filepath = os.path.join(directory, step, 'metrics.csv')
        with open(filepath, 'r') as f:
            data[step] = pd.read_csv(f, header=0, index_col=0)
    return data


def safe_raw_metrics(data, directory):
    for step in WORKFLOW_STEPS:
        for group in HOST_GROUPS:
            for metric in RAW_METRICS:
                filename = '{}.csv'.format(metric)
                subdirectory = os.path.join(directory, step, group)
                if not os.path.exists(subdirectory):
                    os.makedirs(subdirectory)
                filepath = os.path.join(subdirectory, filename)
                with open(filepath, 'w') as f:
                    data[step][group][metric].to_csv(f)


def load_raw_metrics(directory):
    data = dict()
    for step in WORKFLOW_STEPS:
        data[step] = dict()
        for group in HOST_GROUPS:
            data[step][group] = dict()
            for metric in RAW_METRICS:
                filename = '{}.csv'.format(metric)
                filepath = os.path.join(directory, step, group, filename)
                with open(filepath, 'r') as f:
                    df = pd.read_csv(f, header=0, index_col=0)
                data[step][group][metric] = df
    return data


def load_workflow_statistics(filename):
    return pd.read_csv(filename, header=0)


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(
        description='''
            Download Ganglia metrics obtained as part of a TissueMAPS benchmark
            test. Raw metrics for each host are downloaded and persisted on disk
            in CSV format. In addition, summary statistics are computed for
            groups of hosts (compute, filesystem, database coordinator and
            database worker) and persisted on disk in CSV format as well.
            The program expects a file named ``{cluster}_jobs.csv`` in the
            specified directory that contains the status of each workflow step
            in CSV format.
        '''
    )
    parser.add_argument(
        '-H', '--host', required=True,
        help='IP address or DNS name of the Ganglia server'
    )
    parser.add_argument(
        '-c', '--cluster', required=True,
        help='name of the cluster'
    )
    parser.add_argument(
        '-d', '--directory', required=True,
        help='path to a directory on disk where data should be stored'
    )

    args = parser.parse_args()

    workflow_stats_filename = os.path.join(
        args.directory, '{}_jobs.csv'.format(args.cluster)
    )
    workflow_statistics = load_workflow_statistics(workflow_stats_filename)
    raw_data = download_raw_metrics(args.host, args.cluster, workflow_statistics)

    output_dir = os.path.join(args.directory, args.cluster)
    safe_raw_metrics(raw_data, output_dir)

    formatted_data = format_raw_metrics(raw_data, workflow_statistics)
    safe_formatted_metrics(formatted_data, output_dir)
