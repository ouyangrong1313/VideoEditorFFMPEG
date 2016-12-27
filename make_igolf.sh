#log function
function README_OUT()
{
  # $1：参数为将生成的文件列表字符串
  LOG_NAME="README.txt"
  CUR_TIME=`echo | date "+%Y-%m-%d %H:%M:%S"`

  echo "//*************************************************************
  //* 创 建 者： 
  //* 工程名称： ${LIB_NAME}
  //* 创建时间： 
  //* 生成时间： ${CUR_TIME}
  //* 当前版本： ${version}
  //* 编译架构： ${VALID_ARCHS}
  //* 编译模式： ${CONFIGURATION}
  //* 编译SDK： ${SDK_NAME}
  //* 包含文件： $1
  //*************************************************************">>${LOG_NAME}
  echo "
  //* 文档说明：
  //因底层音视频通话SDK未使用最新xcode7的编译设置，因此会使基本该SDK的工程app，无法运行在xcode7中的模似器中，
  //但可以运行真机设备中，同时xcode6.*都将适用。 本SDK，未支持i386，所以不能在模似器上iphone5上运行.
  //默认project工程 {CONFIGURATION} = Debug， 如果不是用于调试，而是用于发行,请改成release. Lib包的质量将会缩减。
  ">>${LOG_NAME}
}

#//*************************************************************
#//* 创建者：陈胜  chensheng12330@gmail.com
#//* 创建时间： 2015.12.15
#//* 修改时间： 2015.*.*
#//* 当前版本： v1.0
#//* 文档名称：lib_lipo  for makefile.
#//* 文档说明：tmbChatMob 脚本打包，将 XMPPCapabilities.mom, XMPPMessageArchiving.momd, XMPPRoom.momd, XMPPRoomHybrid.momd, XMPPRoster.mom, XMPPvCard.momd, include,
#             libTMBVoIPMob.bundle, libtmbChatMob.a 进行lib zip压缩打包成  tmbChatMob.zip,将此zip进行版本的发行.

#//*************************************************************
#
# define static library target name
#=${PROJECT_NAME}
#LIB_NAME="testLib"

#LIB_Resource 资源包bundle定义，如果无引用的资源包,置空即可
LIB_Resource_Target=“libIGolfPlayer”

LIB_NAME=${PROJECT_NAME}
# define output folder environment variable
UNIVERSAL_OUTPUTFOLDER=${BUILD_DIR}/${CONFIGURATION}-universal
DEVICE_DIR=${BUILD_DIR}/${CONFIGURATION}-iphoneos
SIMULATOR_DIR=${BUILD_DIR}/${CONFIGURATION}-iphonesimulator

# Step 1. Build Device and Simulator versions
# insert such -arch i386 before BUILD_DIR assign arch
xcodebuild -target "${LIB_NAME}" ONLY_ACTIVE_ARCH=NO -configuration ${CONFIGURATION} -sdk iphoneos  BUILD_DIR="${BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}" clean build
xcodebuild -target "${LIB_NAME}" ONLY_ACTIVE_ARCH=NO -configuration ${CONFIGURATION} -sdk iphonesimulator  BUILD_DIR="${BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}" clean build

#根据配置，是否需要Build 资源包
if [ "$LIB_Resource_Target" ]
then
xcodebuild -target "${LIB_Resource_Target}" -configuration ${CONFIGURATION} -sdk iphoneos  BUILD_DIR="${BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}"
fi

# Cleaning the oldest and make sure the output directory exists
if [ -d "${UNIVERSAL_OUTPUTFOLDER}" ]
then
rm -rf "${UNIVERSAL_OUTPUTFOLDER}"
fi
mkdir -p "${UNIVERSAL_OUTPUTFOLDER}"

# Step 2. Create universal binary file using lipo
lipo -create "${DEVICE_DIR}/lib${LIB_NAME}.a" "${SIMULATOR_DIR}/lib${LIB_NAME}.a" -output "${UNIVERSAL_OUTPUTFOLDER}/lib${LIB_NAME}.a"

# Last touch. copy the header files. Just for convenience
cp -R "${DEVICE_DIR}/include" "${UNIVERSAL_OUTPUTFOLDER}/"


#zip for lib resource.
ZIP_LIB_A="${UNIVERSAL_OUTPUTFOLDER}/lib${LIB_NAME}.a"
ZIP_LIB_I="${UNIVERSAL_OUTPUTFOLDER}/include/"
ZIP_LIB_R=${LIB_Resource_Path}
ZIP_LIB_O="${UNIVERSAL_OUTPUTFOLDER}/${LIB_NAME}.zip"
#ZIP_LIB_S="lib${LIB_NAME}.a include"

cd "${UNIVERSAL_OUTPUTFOLDER}"

if [ -f "${ZIP_LIB_A}" ]
then

#------------README------------------
#生成README.txt文档

OUTPUT_FILES="lib${LIB_NAME}.a ${README} include/ resources/"
if [ $LIB_Resource_Target ]
  then
    OUTPUT_FILES="${OUTPUT_FILES} ${LIB_Resource_Target}.bundle"
fi
README_OUT "${OUTPUT_FILES}"
#------------------------------


#清空build包
BUILD_DIR="${SRCROOT}/build/"
rm -rf "${BUILD_DIR}"

###############################################################
open "${UNIVERSAL_OUTPUTFOLDER}/"
exit 0


#根据是否需要build bundle参数设置，选择性的打包
if [ $LIB_Resource_Target ]
  then
    zip -r "${ZIP_LIB_O}" "lib${LIB_NAME}.a" "include/" "${README}" "resources/" "${LIB_Resource_Target}.bundle"
  else
    zip -r "${ZIP_LIB_O}" "lib${LIB_NAME}.a" "include/" "${README}" "resources/"
fi

#判断zip是否生成
SH_INFO="脚本运行失败. -_-!!!"
if [ -f "$ZIP_LIB_O" ]
  then
  SH_INFO="脚本运行成功. *^_^* "
fi
CUR_TIME=`echo | date`
  echo "/*---------${CUR_TIME}------------------------*/"
  echo " *-------->${SH_INFO}------"
  echo "/*--------{Sherwin.Chen}-----------------------*/"
fi

#open the universal dir
open "${UNIVERSAL_OUTPUTFOLDER}/"

#delete DEVICE and SIMULATOR build file
#rm -rf "${DEVICE_DIR}"
#rm -rf "${SIMULATOR_DIR}"
