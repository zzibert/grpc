#!/bin/bash
 
 
#Constants
COMMAND=$1
 
# Platform configs folder settings
CONFIG_FOLDER="platform-configs"
mkdir -p $CONFIG_FOLDER
 
#Zookeeper settings
ZKSERVER="zookeeper-development-01.shared.us-west-2.aws.plume.tech:2181"
ZKPATH="/infrastructure/services/platform-config"
 
#Into which bucket to upload and under what key
BUCKET="plume-development-global-platform-config"
KEY="opensync/custom-tool.tar.gz"
TAR_NAME=$(echo $KEY | rev | cut -d '/' -f1 | rev)
 
#Which root zk enteries to modify!
MODIFYROOTS=("/development/us-west-2/dev/osacademy" "/development/us-west-2/dev/opensync")
#MODIFYROOTS=("/development/us-west-2/dev/slodev1") # For testing
 
TAR_PATH=$CONFIG_FOLDER/$TAR_NAME
BUCKET_STRING=s3://$BUCKET/$KEY
 
# Command implementations! #
 
download()
{
    echo "Downloading from bucket $BUCKET"
    aws2 s3 cp $BUCKET_STRING $CONFIG_FOLDER &&
    tar -xzvf $TAR_PATH -C $CONFIG_FOLDER | wc -l &&
        echo "Extracted files from tar" || echo "Download failed"
}
 
upload()
{
    [ ! -f $TAR_PATH ] && echo "$TAR_PATH does not exist" && exit
    MD5=$(md5sum $TAR_PATH | cut -d ' ' -f1)
        [ ${#MD5} -lt 20 ] && echo "MD5 is not correct: $MD5"
    echo "Uploading to bucket $BUCKET"
    aws2 s3 cp $TAR_PATH $BUCKET_STRING &&
    echo "Uploaded to bucket updating zk config!" || exit
        NODE_CONTENT="{\"bucket\":\"$BUCKET\",\"key\":\"$KEY\",\"md5sum\":\"$MD5\"}"
    echo $NODE_CONTENT
    for zk_root in ${MODIFYROOTS[@]}
    do
        ZK_NODE_PATH=$zk_root$ZKPATH
        echo "Creating $ZK_NODE_PATH with content $NODE_CONTENT"
        zookeepercli --servers $ZKSERVER -c create $ZK_NODE_PATH $NODE_CONTENT &&
        echo "Created new node!" ||
        (echo "Node already exists, updating content"
        zookeepercli --servers $ZKSERVER -c set $ZK_NODE_PATH $NODE_CONTENT)
        echo -n "New node content:  "
        zookeepercli --servers $ZKSERVER -c get $ZK_NODE_PATH
        echo "Creating $ZK_NODE_PATH completed!"
    done
}
 
state()
{
        LOCAL_TAR_MD5=$(md5sum $TAR_PATH | cut -d ' ' -f1)
    echo "Getting S3 bucket tar info"
    aws2 s3 ls s3://$BUCKET/$KEY
    echo
    echo "Getting zk nodes content"
    for zk_root in ${MODIFYROOTS[@]}
    do
                echo
        ZK_NODE_PATH=$zk_root$ZKPATH
        echo "Content in $ZK_NODE_PATH is:"
        ZK_CONTENT=$(zookeepercli --servers $ZKSERVER -c get $ZK_NODE_PATH)
                echo $ZK_CONTENT
                ZK_MD5=$(echo $ZK_CONTENT | jq -r .md5sum)
                #echo "comparing $ZK_MD5 $LOCAL_TAR_MD5"
                [ "$ZK_MD5" = "$LOCAL_TAR_MD5" ] && echo "md5 matches local tar md5" || echo "MD5 Sum does not match! Possible update!"
    done
}
 
prepare()
{
    echo "Preparing configurations from folder $CONFIG_FOLDER"
    MAN_FILE=$CONFIG_FOLDER/manifest.json
    rm -f $MAN_FILE
    echo "{\"name\":\"custom-$(date +%F_%R)\",\"version\":\"1.0.0\",\"date\":\"$(date +%F_%R)\",\"uploader\":\"$USER\"}" > $MAN_FILE
    rm -f $TAR_PATH
    cd $CONFIG_FOLDER
    echo "here"
    tar -czf $TAR_NAME --exclude='schema.conf' --exclude='platforms.conf' --wildcards *.conf *.json
    cd -
    echo "Configurations prepared!"
}
 
delete()
{
    # Remove modifyroot2 and remove only from real list when ready!
    for zk_root in ${MODIFYROOTS[@]}
    do
        ZK_NODE_PATH=$zk_root$ZKPATH
        echo "Deleting node $zk_root$ZKPATH"
        zookeepercli --servers $ZKSERVER -c get $ZK_NODE_PATH &&
        (echo "Deleting node"
        zookeepercli --servers $ZKSERVER -c delete $ZK_NODE_PATH
        echo -n "Node content after delete: "
        zookeepercli --servers $ZKSERVER -c get $ZK_NODE_PATH) || echo "Node does not exsist, doing nothing!"
        echo "Deleting $ZK_NODE_PATH completed!"
    done
    echo "Done deleting zk nodes!"
}
 
check_user()
{
        read -p "Are you sure $1 (y/n)? " choice
        case "$choice" in
                y|Y|ye|YE|yes|YES )
                        ;;
                * )
                        echo "exiting"
                        exit 0
                        ;;
        esac
}
 
show_controller_logs()
{
        echo "Configure ssh call in script to see controller logs!"
        # ssh <user>@<server> tail -n1000 -f /var/log/controller/controller.log | grep PlatformConfigService
}
 
# Call correct command implementation!
case $COMMAND in
    download)
            check_user "you want to download configs"
        echo "Download started!"
        download
        ;;
    upload)
                check_user "you want to upload new configs"
        echo "Upload started!"
        upload
                show_controller_logs
        ;;
    prepare)
        echo "Preparing started!"
        prepare
        ;;
    state)
        state
        ;;
    delete)
            check_user "delete current configs"
        echo "Deleting started!"
        delete
        ;;
    *)
        echo "Unknown command \"$COMMAND\""
        ;;
esac
