<%!
from time import strftime as time
import re

# pattern to match a bussed port, i.e. foo[WIDTH-1:0] will match
#    group(1) ==> "foo"
#    group(2) ==> "[WIDTH-1:0]"
BUSPORT_PAT = re.compile(r"(\S+)(\[\S+\])")

def is_real_param(param):
    """ check to see if this is an integer """

    if 'range' in param:
        return True

    if 'type' in param and param['type'] == "integer":
        return True

    if 'type' in param and param['type'] == "real":
        return True

    return False

def is_vector_param(param):
    """ check to see if this is a vector """

    if 'vector' in param:
        return True

    return False

def gen_param_string(pdict):
    """ generate a parameter string for the dictionary"""

    param_list = pdict.keys()
    num_params = len(param_list)
    paramcount = 0
    output_str = ""
    for param in param_list:
        paramcount += 1
        param_str = ""


        vector_str = ""
        if 'vector' in pdict[param]:
            msb = int(pdict[param]['vector']) - 1
            vector_str = f"[{msb}:0] "

        if 'default' in pdict[param]:
            default = pdict[param]['default']
            if 'type' in pdict[param]:
                if pdict[param]['type'] == "real": # convert the real values to int for blackbox as float/real are not synthesizable
                    default = int(default)
            if is_real_param(pdict[param]) or is_vector_param(pdict[param]):
                # integers and vectors don't need quotes
                param_str = f"  parameter {vector_str}{param} = {default}"
            else:
                param_str = f"  parameter {vector_str}{param} = \"{default}\""

        else:
            param_str = f"  parameter {param}"

        # Add suffix of description, if any.#
        # Include ',' if not last parameter
        if 'desc' in pdict[param]:
            # has description
            if paramcount != num_params:
                param_str = f"{param_str}, // {pdict[param]['desc']}\n"
            else:
                # last element
                param_str = f"{param_str} // {pdict[param]['desc']}"
        else:
            if paramcount != num_params:
                param_str = f"{param_str},\n"
            else:
                # last element
                param_str = f"{param_str}"

        output_str += param_str

    return output_str

def generate_port_str(port):
    """ reprocess port in case it is bussed

    i.e. if we have port[foo], this will return "[foo] port"
    so it can be put into the module declaration cleanly"
    """

    matched = re.match(BUSPORT_PAT, port)
    if matched:
        busport = matched.group(2)
        portname = matched.group(1)
        return f"{busport} {portname}"

    return port        
%>\
//
// ${dd['name']} black box model
% if 'desc' in dd:
// ${dd['desc']}
% endif
//
// Copyright (c) ${"%Y" | time} Rapid Silicon, Inc.  All rights reserved.
//
<%
    has_parameters = False
    has_properties = False

    if 'parameters' in dd:
        has_parameters = True
    if 'properties' in dd:
        has_properties = True

    param_str = ""
    if has_parameters:
        param_str = gen_param_string(dd['parameters'])

    prop_str = ""

    if has_properties:
        prop_str = gen_param_string(dd['properties'])
%>\
`celldefine
(* blackbox *)
##
## header depends on whether or not there are parameters and properties
##
## BOTH PARAMETERS and PROPERTIES
% if has_parameters and has_properties:
module ${dd['name']} #(
${param_str}
##`ifdef RAPIDSILICON_INTERNAL
,${prop_str}
##`endif // RAPIDSILICON_INTERNAL
  ) (
% endif
## ONLY PARAMETERS
% if has_parameters and not has_properties:
module ${dd['name']} #(
${param_str}
  ) (
% endif
## ONLY PROPERTIES
% if not has_parameters and has_properties:
module ${dd['name']}
##`ifdef RAPIDSILICON_INTERNAL
  #(
${prop_str}
  )
##`endif // RAPIDSILICON_INTERNAL
  (
% endif
## NEITHER PARAMETERS NOR PROPERTIES
% if not has_parameters and not has_properties:
module ${dd['name']} (
% endif      
<%if 'ports' in dd:
     portlist = []
     for port in dd['ports']:

         # convert "portname[MSB:0]" to "[MSB:0] portname"
	 portname = generate_port_str(port)
	 
	 # check for existence of attribute
	 if 'bb_attributes' in dd['ports'][port]:
 	    prefix = dd['ports'][port]['bb_attributes']
	    prefix_str = f"(* {prefix} *)\n  "
         else:
	    prefix_str = ""

         # check for reg type
         is_reg_type = False
         if 'type' in dd['ports'][port] and dd['ports'][port]['type'] == "reg":
             is_reg_type = True
         if dd['ports'][port]['dir'] == "input":
             portlist.append(f"{prefix_str}input logic {portname}")
         if dd['ports'][port]['dir'] == "output":
             if is_reg_type:
                portlist.append(f"{prefix_str}output reg {portname}")
	     else:
                portlist.append(f"{prefix_str}output logic {portname}")
     portlist_str = ',\n  '.join(portlist)
%>\
  ${portlist_str}
);
endmodule
`endcelldefine
