#!/usr/bin/env python3
"""
Add a Run Script build phase to the Molten target.
This script modifies the project.pbxproj file to add the set-build-number.sh script.
"""

import re
import sys
import uuid

def generate_xcode_uuid():
    """Generate a UUID in Xcode's format (24 hex characters)."""
    return uuid.uuid4().hex[:24].upper()

def add_build_phase(project_file):
    """Add the Run Script build phase to project.pbxproj."""

    with open(project_file, 'r') as f:
        content = f.read()

    # Generate a new UUID for the build phase
    build_phase_uuid = generate_xcode_uuid()

    # Create the PBXShellScriptBuildPhase entry
    shell_script_phase = f"""/* Begin PBXShellScriptBuildPhase section */
\t\t{build_phase_uuid} /* Set Build Number from Git */ = {{
\t\t\tisa = PBXShellScriptBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\tinputFileListPaths = (
\t\t\t);
\t\t\tinputPaths = (
\t\t\t);
\t\t\tname = "Set Build Number from Git";
\t\t\toutputFileListPaths = (
\t\t\t);
\t\t\toutputPaths = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t\tshellPath = /bin/sh;
\t\t\tshellScript = "${{PROJECT_DIR}}/Scripts/set-build-number.sh\\n";
\t\t}};
/* End PBXShellScriptBuildPhase section */
"""

    # Find where to insert the PBXShellScriptBuildPhase section
    # Insert it after PBXCopyFilesBuildPhase section
    copy_files_end = content.find('/* End PBXCopyFilesBuildPhase section */')
    if copy_files_end == -1:
        print("Error: Could not find PBXCopyFilesBuildPhase section")
        return False

    # Find the next newline after the end marker
    insert_pos = content.find('\n', copy_files_end) + 1

    # Insert the shell script section
    content = content[:insert_pos] + '\n' + shell_script_phase + '\n' + content[insert_pos:]

    # Now add the reference to the Molten target's buildPhases array
    # Find the Molten target (F5A13C4A2E890146002C0F7A)
    target_pattern = r'(F5A13C4A2E890146002C0F7A /\* Molten \*/ = \{[^}]*buildPhases = \(\s*)'
    match = re.search(target_pattern, content, re.DOTALL)

    if not match:
        print("Error: Could not find Molten target buildPhases")
        return False

    # Find the position after "buildPhases = ("
    build_phases_start = match.end()

    # Insert the new build phase reference at the beginning (before Sources)
    # This ensures it runs first
    new_phase_ref = f"\t\t\t\t{build_phase_uuid} /* Set Build Number from Git */,\n"
    content = content[:build_phases_start] + new_phase_ref + content[build_phases_start:]

    # Write the modified content back
    with open(project_file, 'w') as f:
        f.write(content)

    print(f"✅ Successfully added build phase with UUID: {build_phase_uuid}")
    print(f"   Added to Molten target's buildPhases array")
    return True

if __name__ == '__main__':
    project_file = '/Users/binde/projects/catalog/Molten.xcodeproj/project.pbxproj'

    # Create backup first
    import shutil
    backup_file = project_file + '.backup'
    shutil.copy2(project_file, backup_file)
    print(f"📋 Created backup: {backup_file}")

    if add_build_phase(project_file):
        print("✅ Project file modified successfully")
        print("   You can now build the project to test the build number script")
        sys.exit(0)
    else:
        # Restore backup on error
        shutil.copy2(backup_file, project_file)
        print("❌ Error modifying project file (restored from backup)")
        sys.exit(1)
