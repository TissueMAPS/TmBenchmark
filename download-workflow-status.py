#!/usr/bin/env python
import os
import pandas as pd

from tmclient import TmClient


def download_workflow_statistics(host, username, password):
    client = TmClient(
        host=host, port=80, username=username, password=password,
        experiment_name='benchmark'
    )
    data = client.get_workflow_status(depth=5)
    columns = ('name', 'created_at', 'updated_at', 'memory', 'time', 'cpu_time')
    def append_recursively(task, values):
        row = list()
        for c in columns:
            row.append(task[c])
        values.append(tuple(row))
        for t in task.get('subtasks', list()):
            if t is None:
                continue
            append_recursively(t, values)
    values = list()
    append_recursively(data, values)
    df = pd.DataFrame(values, columns=columns)
    return df


def save_workflow_statistics(data, filename):
    data.to_csv(filename, index=False)


def load_workflow_statistics(filename):
    data = pd.read_csv(filename, header=0)


if __name__ == '__main__':

    import argparse
    import getpass

    parser = argparse.ArgumentParser(
        description='''
            Download workflow statistics obtained as part of a TissueMAPS
            benchmark test. Statistics are unnested and persisted in a file
            on disk in CSV format.
        '''
    )
    parser.add_argument(
        '-H', '--host', required=True,
        help='IP address or DNS name of the TissueMAPS server'
    )
    parser.add_argument(
        '-p', '--provider', required=True,
        help='name of the cloud provider'
    )
    parser.add_argument(
        '-c', '--cluster', required=True,
        help='name of the cluster'
    )
    parser.add_argument(
        '-d', '--data-dir', dest='data_dir', required=True,
        help='path to a directory on disk where data should be stored'
    )

    args = parser.parse_args()

    user = 'mustermann'
    message = 'Enter password for user "{0}": '.format(user)
    password = getpass.getpass(message)
    if not password:
        raise ValueError('No password provided for user "{0}"'.format(user))

    data = download_workflow_statistics(args.host, user, password)

    output_dir = os.path.join(args.data_dir, args.provider)
    if not os.path.exists(output_dir):
        print('Create output directory: {}'.format(output_dir))
        os.makedirs(output_dir)

    filename = os.path.join(output_dir, '{}_jobs.csv'.format(args.cluster))
    save_workflow_statistics(data, filename)
