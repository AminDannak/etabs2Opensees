source model.tcl
set Pi [expr 4*atan(1)]
 set eig [eigen 3]
 puts "first mode period is: [expr 2*$Pi/([lindex $eig 0])**0.5]"