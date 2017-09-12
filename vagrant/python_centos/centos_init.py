#!/usr/bin/env python

import yum
import urllib
import boto3
import tarfile
#import os


def install_pkg(pkg_name):
    yb = yum.YumBase()
    yb.conf.assumeyes = True
    yb.install(name=pkg_name)


def download_file_by_url(url, full_filename):
    ## and try and check exception, add retries
    testfile = urllib.URLopener()
    testfile.retrieve(url, full_filename)


def download_file_from_s3(bucket_name, src_filename, dest_filename):
    ## and try and check exception, add retries
    # os.environ["AWS_SHARED_CREDENTIALS_FILE"] = "/home/vagrant/demo/vagrant/python_centos/.aws/credentials"
    s3_client = boto3.client('s3')
    s3_client.download_file(bucket_name, src_filename, dest_filename)

def extract_file(filename):
    if (filename.endswith("tar.gz")):
        tar = tarfile.open(filename, "r:gz")
        tar.extractall()
        tar.close()


if __name__ == "__main__":
    install_pkg('mc')
    download_file_from_s3('ansible-demo1', 'jdk-8u144-linux-x64.tar.gz', '/home/vagrant/jdk8-x64.tar.gz')
    extract_file('/home/vagrant/jdk8-x64.tar.gz')
#    download_file_by_url("https://s3-us-west-2.amazonaws.com/lerkasan/Samsara-1.3.5.RELEASE.jar","/home/vagrant/Samsara.jar")


