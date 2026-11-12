#!/usr/bin/env tclsh
# A pretend lamp with an HTTP API, so there is something to transduce.
#
#   tclsh demo/lamp.tcl ?port?          default port 4100
#
#   GET  /devices                 list lamps and their state
#   GET  /devices/{id}            one lamp
#   PUT  /devices/{id}/state      body {"state": "on"|"off"}; creates the lamp if new
#   GET  /openapi.json            the spec to paste into Actuator
#
# Every change is printed to stdout, which is the point: watch this terminal
# while you POST to Actuator.

set port [expr {[llength $argv] ? [lindex $argv 0] : 4100}]
array set lamps {lamp-1 off lamp-2 off}

proc json_lamps {} {
    global lamps
    set items {}
    foreach id [lsort [array names lamps]] {
        lappend items [format {{"id": "%s", "state": "%s"}} $id $lamps($id)]
    }
    return "\[[join $items ,]\]"
}

proc openapi {} {
    global port
    return [string map [list PORT $port] {
{"openapi": "3.0.3",
 "info": {"title": "Demo lamp", "version": "1"},
 "servers": [{"url": "http://localhost:PORT"}],
 "paths": {
   "/devices": {"get": {"operationId": "listDevices", "summary": "List lamps"}},
   "/devices/{id}": {"get": {"operationId": "getDevice", "summary": "One lamp"}},
   "/devices/{id}/state": {"put": {"operationId": "setState", "summary": "Set a lamp on or off"}}
 }}
}]
}

proc reply {sock status body} {
    puts $sock "HTTP/1.1 $status\r\nContent-Type: application/json\r\nContent-Length: [string length $body]\r\nConnection: close\r\n"
    puts -nonewline $sock $body
    flush $sock
    close $sock
}

proc handle {sock} {
    global lamps
    fconfigure $sock -translation {auto lf} -encoding utf-8 -blocking 1
    if {[gets $sock line] < 0} { close $sock; return }
    lassign $line method path
    set length 0
    while {[gets $sock h] > 0} {
        if {[regexp -nocase {^content-length:\s*(\d+)} $h -> n]} { set length $n }
    }
    set body [expr {$length ? [read $sock $length] : ""}]

    switch -regexp -matchvar m -- "$method $path" {
        {^GET /openapi\.json$}            { reply $sock "200 OK" [openapi] }
        {^GET /devices$}                  { reply $sock "200 OK" [json_lamps] }
        {^GET /devices/([^/]+)$} {
            set id [lindex $m 1]
            if {[info exists lamps($id)]} {
                reply $sock "200 OK" [format {{"id": "%s", "state": "%s"}} $id $lamps($id)]
            } else {
                reply $sock "404 Not Found" {{"error": "no such lamp"}}
            }
        }
        {^PUT /devices/([^/]+)/state$} {
            set id [lindex $m 1]
            if {![regexp {"state"\s*:\s*"(on|off)"} $body -> state]} {
                reply $sock "400 Bad Request" {{"error": "body must be {\"state\": \"on\"|\"off\"}"}}
                return
            }
            set was [expr {[info exists lamps($id)] ? $lamps($id) : "absent"}]
            set lamps($id) $state
            puts "[clock format [clock seconds] -format %H:%M:%S]  $id: $was -> $state"
            reply $sock "200 OK" [format {{"id": "%s", "state": "%s", "was": "%s"}} $id $state $was]
        }
        default { reply $sock "404 Not Found" {{"error": "no route"}} }
    }
}

socket -server {apply {{sock addr p} { handle $sock }}} $port
puts "lamp server on http://localhost:$port  (spec at /openapi.json)"
vwait forever
