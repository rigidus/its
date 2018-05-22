# If the environment variable BASICS is set to "yes", only build
# the basics; ITS, tools, infastructure.
if {![info exists env(BASICS)]} {
    set env(BASICS) "no"
}

proc abort {} {
    puts ""
    puts "The last command timed out."
    exit 1
}

proc type s {
    sleep .1
    foreach c [split $s ""] {
        send -- $c
        if [string match {[a-zA-Z0-9]} $c] {
	    expect -nocase $c
	} else {
	    expect "?"
	}
	sleep .03
    }
}

proc respond { w r } {
    expect -exact $w
    type $r
}

proc pdset {} {
    expect "SYSTEM JOB USING THIS CONSOLE"
    sleep 1
    type "\032"

    respond "Fair" ":pdset\r"
    set t [timestamp]
    respond "PDSET" [expr [timestamp -seconds $t -format "%Y"] / 100]C
    type [timestamp -seconds $t -format "%y%m%dD"]
    type [timestamp -seconds $t -format "%H%M%ST"]
    type "!."
    expect "DAYLIGHT SAVINGS" {
        type "N"
	respond "IT IS NOW" "Q"
    } "IT IS NOW" {
        type "Q"
    } "ITS revived" {
        type "Q"
    }
    expect ":KILL"
}

proc shutdown {} {
    global emulator_escape
    respond "*" ":lock\r"
    expect "_"
    send "5kill"
    respond "GO DOWN?\r\n" "y"
    respond "BRIEF MESSAGE" "\003"
    respond "_" "q"
    expect ":KILL"
    respond "*" ":logout\r"
    respond "NOW IN DDT" $emulator_escape
}

proc ip_address {string} {
    set x 0
    set octets [lreverse [split $string .]]
    for {set i 0} {$i < 4} {incr i} {
	incr x [expr {256 ** $i * [lindex $octets $i]}]
    }
    format "%o" $x
}

proc build_macsyma_portion {} {
    respond "*" "complr\013"
    respond "_" "\007"
    respond "*" "(load \"liblsp;iota\")"
    respond "274630" "(load \"maxtul;docgen\")"
    respond "300052" "(load \"maxtul;mcl\")"
    respond "302615" "(load \"maxdoc;mcldat\")"
    respond "302615" "(load \"libmax;module\")"
    respond "303351" "(load \"libmax;maxmac\")"
    expect "307161"
    type "(todo)"
    expect ") \r"
    type "(todoi)"
    expect {
	") \r" {
	}
        "NIL" {
	}
    }
    type "(mapcan "
    type "#'(lambda (x) (cond ((not (memq x\r"
    type "'(SETS TRANSS MTREE TRHOOK EDLM)\r"
    type ")) (doit x)))) (append todo todoi))"
    set timeout 1000
    expect {
	";BKPT" {
	    type "(quit)"
	}
        "NIL" {
	    type "(quit)"
	}
    }
    set timeout 100
}

set timeout 100
expect_after timeout abort

set ip [ip_address [lindex $argv 0]]
set gw [ip_address [lindex $argv 1]]

source $build/mark.tcl
source $build/basics.tcl

if {$env(BASICS)!="yes"} {
    source $build/misc.tcl
    source $build/lisp.tcl
    source $build/scheme.tcl
    source $build/muddle.tcl
    source $build/sail.tcl
}

bootable_tapes

# make output.tape

respond "*" $emulator_escape
create_tape "$out/output.tape"
type ":dump\r"
respond "_" "dump links full list\r"
respond "LIST DEV =" "tty\r"
respond "TAPE NO=" "1\r"
expect -timeout 3000 "REEL"
respond "_" "rewind\r"
respond "_" "icheck\r"
expect -timeout 3000 "_"
type "quit\r"

shutdown
quit_emulator
