#
# copy germline to desired director and unarchive it
#

x=$(hostname)
echo Copying germline to $2 on host $x
gfile=$1
cp -f ${gfile}.tgz $2
cd $2
tar xf ${gfile}.tgz
