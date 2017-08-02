TissueMAPS benchmark tests
==========================


Requirements
------------

Benchmark tests will be controlled from a local machine, which will interact with remote cloud-based servers over the internet (using *SSH* for deployment and *HTTP* for running the tests).

#### Operating system

The controlling machine should be *UNIX* based, i.e. either *MacOSX* or *Linux*, mainly because [Ansible](https://docs.ansible.com/ansible/), which we use to deploy *TissueMAPS* in the cloud, doesn't run on *Windows* (see [Ansible docs](https://docs.ansible.com/ansible/intro_windows.html#using-a-windows-control-machine) for details).


#### Software

The controlling machine further needs to have [Python](https://www.python.org/) installed as well as its package manager [pip](https://pip.pypa.io/en/stable/).

In addition, you need [git](https://git-scm.com/), [OpenSSH](https://www.openssh.com/), [OpenSSL](https://www.openssl.org/), [GCC](https://gcc.gnu.org/>) and [time](https://www.gnu.org/software/time/).

Tests are performed by Bash scripts provided via the *tmbenchmark* repository:

    $ git clone https://github.com/tissuemaps/tmbenchmarks ~/tmbenchmarks

These scripts use command line interfaces exposed by the [tmdeploy](https://pypi.python.org/pypi/tmdeploy) and [tmclient](https://pypi.python.org/pypi/tmclient) Python packages. We recommend installing packages into a separate [Python virtual environment](https://virtualenv.pypa.io/en/stable/):

    $ virtualenv ~/.envs/tmbenchmark
    $ source ~/.envs/tmbenchmark/bin/activate
    $ pip install -r ~/tmbenchmarks/requirements.txt


#### Data

Benchmarks are based on the image-based transcriptomics data set ([Battich et al. 2013](https://www.nature.com/nmeth/journal/v10/n11/full/nmeth.2657.html?foxtrotcallback=true)). Images are publicly available on [figshare](https://figshare.com):

    $ wget

> FIXME


#### Example installation for CentOS-7 Linux distribution

Install system packages as `root` user:

    $ yum update -y
    $ yum install -y git gcc epel-release time openssl-devel
    $ yum install -y python-devel python-setuptools python-pip python-virtualenv

Install Python packages as non-privilaged user into virtual environment:

    $ virtualenv ~/.envs/tmbenchmark
    $ source ~/.envs/tmbenchmark/bin/activate
    $ pip install ~/tmbenchmark/requirements.txt


Provisioning infrastructure and deploying software
--------------------------------------------------

The ``setup`` subdirectory of the repository provides setup configuration files to build architectures using the ``tm_deploy`` command line tool.

There are two types of architectures:

    * standalone: single-server setup
    * cluster: multi-server setup with separate compute, filesytem and database servers (and a monitoring system)

The number indicates the total number of CPU cores that are allocated to *TissueMAPS* for parallel execution of computational jobs. Note that in case of a ``standalone`` setup, the database servers run on the same host. We therefore use machine flavors with more CPU cores to provide dedicated resources to the database servers to prevent that they compete with computational jobs for resources. In case of a ``cluster`` setup, the database servers reside on separte hosts.

Specify your cloud provider and the cluster architectures which you would like to set up and run the tests against. For example, to build a cluster with 32 CPU cores on ScienceCloud:

    $ ~/tmbenchmarks/build.sh -p sciencecloud -c cluster-32

The setup files can be found in ``~/tmbenchmark/setup/sciencecloud/``.

Run benchmark tests
-------------------

Once the required infrastructure has been provisioned and the software has been deployed, you can run the test:

    $ ~/tmbenchmarks/upload-and-submit.sh -p sciencecloud -c cluster-32 -H $HOST -d $DATA_DIR

where ``HOST`` is the public IP address of the cloud virtual machine that hosts the *TissueMAPS* web server and ``DATA_DIR`` is the path to a local directory that contains the microscope files that should be upload.

You can use the ``tm_inventory`` command line tool to list metadata about servers that have been set up in the cloud (including their IP addresses):

    $ export TM_SETUP=$HOME/tmbenchmark/setup/sciencecloud/cluster-32.yaml
    $ tm_inventory --list

Download analysis results
-------------------------

Once the test has completely, you can download the extracted single-cell feature data:

    $ ~/tmbenchmark/download-results.sh -p sciencecloud -c cluster-32 -H $HOST -d $DATA_DIR

This will write the results as *CSV* files into ``$DATA_DIR/sciencecloud/cluster-32/results``


Download workflow status
------------------------

To calculate duration and speedup of workflow processing, you can download the status for computational jobs:

    $ download-workflow-status.py -p sciencecloud -c cluster-32 -H $HOST -d $DATA_DIR

This will store the job information in CSV format in ``$DATA_DIR/sciencecloud/cluster-32_jobs.csv``.

Download Ganglia metrics
------------------------

    $ download-workflow-status.py -p sciencecloud -c cluster-32 -H $HOST -d $DATA_DIR

This will store the raw metrics as individual files in CSV format in ``$DATA_DIR/sciencecloud/cluster-32`` as a separate subfolder for each step and computed aggregates in CSV format in ``$DATA_DIR/sciencecloud/cluster-32_metrics.csv``.

Logs
----

The provided scripts will automatically redirect standard output and error to dedicated log files in `~/tmbenchmark/logs`.
