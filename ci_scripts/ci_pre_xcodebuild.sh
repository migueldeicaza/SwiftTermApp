#!/bin/sh

#  ci_pre_xcodebuild.sh
#  SwiftTermApp
#
#  Created by Miguel de Icaza on 3/29/22.
#  Copyright © 2022 Miguel de Icaza. All rights reserved.
echo running at 
pwd

echo "let shakeId = \"${SHAKE_ID}\"" > ${CI_WORKSPACE}/SwiftTermApp/Secrets.swift
echo "let shakeKey = \"${SHAKE_SECRET}\"" >> ${CI_WORKSPACE}/SwiftTermApp/Secrets.swift
