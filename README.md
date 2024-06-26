# Command Line Interface to Emacs Launch Interface (CLI2ELI)

## Overview
CLI2ELI is an Emacs package designed to streamline the use of external command line tools within Emacs. It provides a user-friendly interface to seamlessly integrate and launch command line tools from within the Emacs environment.

## Features
- Dynamically generates Emacs interactive functions from command line tool specifications.
- Supports a wide range of command line tools and their various options.
- Easy configuration via JSON files for tool specifications.
- Enhances productivity by enabling the use of CLI tools directly in Emacs.

## Installation
To install CLI2ELI:
1. Clone this repository to your local machine.
2. Add the following lines to your Emacs configuration file:
   ```emacs-lisp
   (add-to-list 'load-path "/path/to/CLI2ELI")
   (require 'cli2eli)
   ```

## Configuration
1. Create a JSON file with the specifications of the command line tool you wish to integrate. For example:
   ```json
   {
     "toolName": "exampleTool",
     "options":
     "options": [
       {"name": "--option1", "description": "Description of option1"},
       {"name": "--option2", "description": "Description of option2"}
     ]
   }
   ```
2. Load the JSON file in Emacs to generate the interactive functions:
   ```emacs-lisp
   (cli2eli-load-tool "/path/to/your-config.json")
   ```

## Usage
After generating the interactive functions, you can directly invoke the commands associated with your external CLI tools in Emacs. Each command will have a unique prefix, as specified in your JSON configuration, ensuring easy access and organization.

Example usage:
- `M-x exampleTool-option1` to execute the `option1` of `exampleTool`.

## How It Works
CLI2ELI reads the provided JSON configuration and dynamically creates Emacs Lisp functions corresponding to each specified command line option. These functions, when invoked, execute the related command line operation and display the output within Emacs, providing a smooth and integrated user experience.


## License
CLI2ELI is released under the [MIT License](LICENSE.md). Feel free to use, modify, and distribute it as per the license terms.
