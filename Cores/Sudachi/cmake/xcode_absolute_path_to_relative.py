import os
import pathlib
import re

# This should be changed to actual absolute paths generated by cmake
PROVENANCE_DIR = '/Volumes/DATA/Code/Provenance'
MOLTEN_DIR = '/Volumes/DATA/Code/Provenance/MoltenVK'

# Path to CMake XCode project files to process
# (This will do recursive processing of all pbxproj files inside )
DIRECTORY_TO_READ = os.getcwd() # Process current directory

# This should be the absolute path to the Core / Vulkan directory
CORE_DIR = PROVENANCE_DIR + '/Cores/Flycast'
VULKAN_DIR = PROVENANCE_DIR + '/MoltenVK'

# Relative path to Core Lib Project Directory
CORE_LIB_DIR = "../flycast"

# Places built library binaries under dolphin-ios/dolphin-build
BUILD_DIR = "../lib"

LIBS_TO_RENAME = []
LIBS_TO_RENAME.append([' = fmt;', ' = fmtd;'])

# Paths to convert to relative path in XCode
SRCROOT_PATH_TO_FIND = CORE_DIR + '/'
SRCROOT_PATH_TO_REPLACE_WITH = '../'
CMAKE_PATH_TO_FIND = CORE_DIR + '/cmake'
CMAKE_PATH_TO_REPLACE_WITH = '../cmake'
#VULKAN_PATH_TO_FIND = VULKAN_DIR
#VULKAN_PATH_TO_REPLACE_WITH = '../../../MoltenVK'
#MOLTEN_PATH_TO_FIND = MOLTEN_DIR
#MOLTEN_PATH_TO_REPLACE_WITH = '../../../MoltenVK/MoltenVK'
SDKROOT_PATH_TO_FIND = r'SDKROOT = .*;'
SDKROOT_PATH_TO_REPLACE_WITH = 'SDKROOT = auto;'
PROJECT_DIR_PATH_TO_FIND = r'projectDirPath = ".*";'
PROJECT_DIR_PATH_TO_REPLACE_WITH = f'projectDirPath = "{CORE_LIB_DIR}";'
SYMROOT_DIR_PATH_TO_FIND = r'SYMROOT = .*;'
SYMROOT_DIR_PATH_TO_REPLACE_WITH = f'BUILD_DIR = {BUILD_DIR};'
CONFIG_BUILD_DIR_PATH_TO_FIND = r'CONFIGURATION_BUILD_DIR = .*;'
CONFIG_BUILD_DIR_PATH_TO_REPLACE_WITH = ''
TARGET_TEMP_DIR_PATH_TO_FIND = r'TARGET_TEMP_DIR = .*;'
TARGET_TEMP_DIR_PATH_TO_REPLACE_WITH = ''
#BUILD_CONFIG_TO_FIND = r'buildConfiguration = ".*"'
#BUILD_CONFIG_TO_REPLACE_WITH = 'buildConfiguration = "Release"'

# Replacements will be processed in this order
replacements = []
replacements.append([SRCROOT_PATH_TO_FIND,SRCROOT_PATH_TO_REPLACE_WITH])
replacements.append([CMAKE_PATH_TO_FIND,CMAKE_PATH_TO_REPLACE_WITH])
#replacements.append([MOLTEN_PATH_TO_FIND,MOLTEN_PATH_TO_REPLACE_WITH])
#replacements.append([VULKAN_PATH_TO_FIND,VULKAN_PATH_TO_REPLACE_WITH])
replacements.append([SDKROOT_PATH_TO_FIND,SDKROOT_PATH_TO_REPLACE_WITH])
replacements.append([PROJECT_DIR_PATH_TO_FIND,PROJECT_DIR_PATH_TO_REPLACE_WITH])
replacements.append([SYMROOT_DIR_PATH_TO_FIND,SYMROOT_DIR_PATH_TO_REPLACE_WITH])
replacements.append([TARGET_TEMP_DIR_PATH_TO_FIND,TARGET_TEMP_DIR_PATH_TO_REPLACE_WITH])
replacements.append([CONFIG_BUILD_DIR_PATH_TO_FIND,CONFIG_BUILD_DIR_PATH_TO_REPLACE_WITH])
#replacements.append([BUILD_CONFIG_TO_FIND,BUILD_CONFIG_TO_REPLACE_WITH])

# Extensions of files to process
extensions = ['.pbxproj', '.xcscheme']
print(f'Reading Directory: {DIRECTORY_TO_READ}')
print(f'$(SRCROOT) to find/replace:', replacements)
print(f'Extensions to find:', extensions)

# Does Find / Replace (regex works)
def find_and_replace(content):
  has_match=False
  for (find_string, replace_string) in replacements:
    if re.search(find_string, content):
      content=re.sub(find_string, replace_string, content)
      has_match=True
  for (find_string, replace_string) in LIBS_TO_RENAME:
    if re.search(find_string, content):
      content=re.sub(find_string, replace_string, content)
      has_match=True
  return content if has_match else ''

# Find Files to Replace
def process_file(file):
  process = False
  for extension in extensions:
    if extension in file:
      process = True
  if process:
    try:
      with open(file, "r") as fh:
        content=find_and_replace(fh.read())
        fh.close()
      if content:
        print(f"Replacing absolute paths in {file}")
        with open(file, "w") as fh:
          fh.write(content)
          fh.close()
    except Exception as e:
      print('Exception: ', file, e)

# Recurse Get all files under current dir
def get_files(path):
  files = os.listdir(path)
  for file in files:
    if path != '.':
      file=f'{path}/{file}'
    if os.path.isdir(file):  
      get_files(file)
    elif os.path.isfile(file):
      process_file(file)

get_files(DIRECTORY_TO_READ)