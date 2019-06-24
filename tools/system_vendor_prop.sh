#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2019 Shivam Kumar Jha <jha.shivam3@gmail.com>
#
# Helper functions

# Store project path
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null && pwd )"

# Common stuff
source $PROJECT_DIR/tools/common_script.sh

# Exit if no arguements
if [ -z "$1" ] ; then
	echo -e "${bold}${red}Supply sytem &/ vendor build.prop as arguements!${nocol}"
	exit
fi

# Get files via either cp or wget
if echo "$1" | grep "https" ; then
	wget -O $PROJECT_DIR/working/system_working.prop $1
else
	cp -a $1 $PROJECT_DIR/working/system_working.prop
fi
if [ ! -z "$2" ] ; then
	if echo "$2" | grep "https" ; then
		wget -O $PROJECT_DIR/working/vendor_working.prop $2
	else
		cp -a $2 $PROJECT_DIR/working/vendor_working.prop
	fi
fi

# system.prop
TSTART=$(grep -nr "# end build properties" $PROJECT_DIR/working/system_working.prop | sed "s|:.*||g")
TSTART=$((TSTART+1))
TEND=$(grep -nr "# ADDITIONAL_BUILD_PROPERTIES" $PROJECT_DIR/working/system_working.prop | sed "s|:.*||g")
TEND=$((TEND-1))
sed -n "${TSTART},${TEND}p" $PROJECT_DIR/working/system_working.prop > $PROJECT_DIR/working/system.prop

# put some properties
printf "\n# Additional properties\n" >> $PROJECT_DIR/working/system.prop
echo "ro.am.reschedule_service=true" >> $PROJECT_DIR/working/system.prop
echo "ro.sys.fw.use_trim_settings=true" >> $PROJECT_DIR/working/system.prop

# Lineage vendor security patch support
if [ $(grep "ro.build.version.release=" $PROJECT_DIR/working/system_working.prop | sed "s|ro.build.version.release=||g" | head -c 2) -lt 9 ]; then
	grep "ro.build.version.security_patch=" $PROJECT_DIR/working/system_working.prop | sed "s|ro.build.version.security_patch|ro.lineage.build.vendor_security_patch|g" >> $PROJECT_DIR/working/system.prop
fi

# Default LCD density
if ! grep -q "ro.sf.lcd_density=" $PROJECT_DIR/working/system.prop; then
	printf "\n# LCD density\n" >> $PROJECT_DIR/working/system.prop
	echo "ro.sf.lcd_density=440" >> $PROJECT_DIR/working/system.prop
fi

# vendor.prop
if [ ! -z "$2" ] ; then
	TSTART=$(grep -nr "ADDITIONAL VENDOR BUILD PROPERTIES" $PROJECT_DIR/working/vendor_working.prop | sed "s|:.*||g")
	TEND=$(wc -l $PROJECT_DIR/working/vendor_working.prop | sed "s| .*||g")
	sed -n "${TSTART},${TEND}p" $PROJECT_DIR/working/vendor_working.prop | sort | sed "s|#.*||g" | sed '/^[[:space:]]*$/d' > $PROJECT_DIR/working/vendor_new.prop
	sed -i -e 's/^/    /' $PROJECT_DIR/working/vendor_new.prop
	sed -i '1 i\PRODUCT_PROPERTY_OVERRIDES += ' $PROJECT_DIR/working/vendor_new.prop
	awk 'NF{print $0 " \\"}' $PROJECT_DIR/working/vendor_new.prop > $PROJECT_DIR/working/vendor_prop.mk
fi

# cleanup
rm -rf $PROJECT_DIR/working/system_working.prop $PROJECT_DIR/working/vendor_new.prop $PROJECT_DIR/working/vendor_working.prop