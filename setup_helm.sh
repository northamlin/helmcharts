#!/bin/bash
helm package moodle/
helm package wordpress/
helm repo index .
