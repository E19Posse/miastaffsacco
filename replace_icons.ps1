# Flutter icon replacement: Material Icons -> UniconsLine
# Run from C:\bmcsacco_app

$libDir = "C:\bmcsacco_app\lib"

# Order matters: longer/more-specific names FIRST to avoid partial matches
$mapping = [ordered]@{
    # account_balance variants (longest first)
    'Icons.account_balance_wallet'    = 'UniconsLine.wallet'
    'Icons.account_balance_outlined'  = 'UniconsLine.university'
    'Icons.account_balance'           = 'UniconsLine.university'
    'Icons.account_circle'            = 'UniconsLine.user_circle'

    # add variants
    'Icons.add_circle_outline'        = 'UniconsLine.plus_circle'
    'Icons.add_card'                  = 'UniconsLine.card_atm'
    'Icons.add'                       = 'UniconsLine.plus'

    # arrow variants
    'Icons.arrow_forward_ios'         = 'UniconsLine.angle_right_b'
    'Icons.arrow_upward'              = 'UniconsLine.arrow_up'
    'Icons.arrow_back'                = 'UniconsLine.arrow_left'

    # bar/area/area chart
    'Icons.area_chart'                = 'UniconsLine.chart_line'
    'Icons.bar_chart'                 = 'UniconsLine.chart_bar'

    # backspace
    'Icons.backspace_outlined'        = 'UniconsLine.backspace'

    # badge
    'Icons.badge'                     = 'UniconsLine.id_card'

    # block/ban
    'Icons.block'                     = 'UniconsLine.ban'

    # calendar variants (longest first)
    'Icons.calendar_today_outlined'   = 'UniconsLine.calendar_alt'
    'Icons.calendar_today'            = 'UniconsLine.calendar_alt'
    'Icons.calendar_month'            = 'UniconsLine.calendar_alt'

    # calculate
    'Icons.calculate_outlined'        = 'UniconsLine.calculator'

    # camera
    'Icons.camera_alt_outlined'       = 'UniconsLine.camera'
    'Icons.camera_alt'                = 'UniconsLine.camera'

    # call
    'Icons.call_received'             = 'UniconsLine.phone_incoming_call'

    # cancel
    'Icons.cancel'                    = 'UniconsLine.times_circle'

    # card
    'Icons.card_membership'           = 'UniconsLine.card_atm'
    'Icons.card_giftcard'             = 'UniconsLine.gift'

    # chat
    'Icons.chat_bubble_outline'       = 'UniconsLine.comment_alt_message'

    # check variants (longest first)
    'Icons.check_circle_outline'      = 'UniconsLine.check_circle'
    'Icons.check_circle_rounded'      = 'UniconsLine.check_circle'
    'Icons.check_circle'              = 'UniconsLine.check_circle'
    'Icons.check'                     = 'UniconsLine.check'

    # chevron
    'Icons.chevron_right'             = 'UniconsLine.angle_right'

    # copy
    'Icons.copy'                      = 'UniconsLine.copy'

    # credit card
    'Icons.credit_card'               = 'UniconsLine.credit_card'

    # dark mode
    'Icons.dark_mode'                 = 'UniconsLine.moon'

    # delete
    'Icons.delete_outline'            = 'UniconsLine.trash_alt'

    # description / file
    'Icons.description'               = 'UniconsLine.file_alt'

    # directions
    'Icons.directions_car'            = 'UniconsLine.car'

    # download
    'Icons.download'                  = 'UniconsLine.download_alt'

    # edit
    'Icons.edit_outlined'             = 'UniconsLine.edit'

    # email
    'Icons.email_outlined'            = 'UniconsLine.envelope_alt'

    # emoji
    'Icons.emoji_events'              = 'UniconsLine.trophy'

    # error
    'Icons.error_outline'             = 'UniconsLine.exclamation_circle'

    # event
    'Icons.event_outlined'            = 'UniconsLine.calendar_alt'
    'Icons.event'                     = 'UniconsLine.calendar_alt'

    # exit
    'Icons.exit_to_app'               = 'UniconsLine.signout'

    # face
    'Icons.face_outlined'             = 'UniconsLine.smile'
    'Icons.face'                      = 'UniconsLine.smile'

    # fingerprint
    'Icons.fingerprint'               = 'UniconsLine.fingerprint'

    # flag
    'Icons.flag_outlined'             = 'UniconsLine.flag'
    'Icons.flag_rounded'              = 'UniconsLine.flag'

    # grid
    'Icons.grid_view'                 = 'UniconsLine.apps'

    # group
    'Icons.group_add'                 = 'UniconsLine.user_plus'
    'Icons.group'                     = 'UniconsLine.users_alt'

    # health
    'Icons.health_and_safety'         = 'UniconsLine.shield_check'

    # headset
    'Icons.headset_mic'               = 'UniconsLine.headphones'

    # home
    'Icons.home'                      = 'UniconsLine.estate'

    # hourglass
    'Icons.hourglass_top_rounded'     = 'UniconsLine.hourglass'
    'Icons.hourglass_top'             = 'UniconsLine.hourglass'
    'Icons.hourglass_bottom'          = 'UniconsLine.hourglass'

    # how_to_vote
    'Icons.how_to_vote_outlined'      = 'UniconsLine.check_square'

    # info
    'Icons.info_outline'              = 'UniconsLine.info_circle'

    # location
    'Icons.location_off_outlined'     = 'UniconsLine.map_marker_slash'
    'Icons.location_on_outlined'      = 'UniconsLine.map_marker'
    'Icons.location_on'               = 'UniconsLine.map_marker'

    # lock variants (longest first)
    'Icons.lock_outline_rounded'      = 'UniconsLine.lock'
    'Icons.lock_outline'              = 'UniconsLine.lock'
    'Icons.lock_rounded'              = 'UniconsLine.lock'
    'Icons.lock_reset'                = 'UniconsLine.lock_alt'

    # logout
    'Icons.logout'                    = 'UniconsLine.signout'

    # manage_accounts
    'Icons.manage_accounts'           = 'UniconsLine.setting'

    # menu_book
    'Icons.menu_book'                 = 'UniconsLine.book_open'

    # notifications variants (longest first)
    'Icons.notifications_outlined'    = 'UniconsLine.bell'
    'Icons.notifications_active'      = 'UniconsLine.bell'
    'Icons.notifications_none'        = 'UniconsLine.bell'
    'Icons.notifications'             = 'UniconsLine.bell'

    # payments
    'Icons.payments'                  = 'UniconsLine.money_bill'

    # people
    'Icons.people_outline'            = 'UniconsLine.users_alt'

    # percent
    'Icons.percent'                   = 'UniconsLine.percentage'

    # person
    'Icons.person_outline'            = 'UniconsLine.user'
    'Icons.person'                    = 'UniconsLine.user'

    # phone
    'Icons.phone_outlined'            = 'UniconsLine.phone'
    'Icons.phone'                     = 'UniconsLine.phone'

    # photo
    'Icons.photo_library'             = 'UniconsLine.images'

    # pie chart
    'Icons.pie_chart_outline'         = 'UniconsLine.chart_pie'
    'Icons.pie_chart'                 = 'UniconsLine.chart_pie'

    # pin
    'Icons.pin_outlined'              = 'UniconsLine.map_pin'
    'Icons.pin'                       = 'UniconsLine.map_pin'

    # place
    'Icons.place_outlined'            = 'UniconsLine.map_marker'

    # point_of_sale
    'Icons.point_of_sale'             = 'UniconsLine.store'

    # radio
    'Icons.radio_button_unchecked'    = 'UniconsLine.circle'

    # receipt variants (longest first)
    'Icons.receipt_long_outlined'     = 'UniconsLine.receipt_alt'
    'Icons.receipt_long'              = 'UniconsLine.receipt_alt'
    'Icons.receipt'                   = 'UniconsLine.receipt'

    # remove
    'Icons.remove_red_eye_outlined'   = 'UniconsLine.eye'
    'Icons.remove'                    = 'UniconsLine.minus'

    # savings
    'Icons.savings_outlined'          = 'UniconsLine.money_bill_stack'
    'Icons.savings'                   = 'UniconsLine.money_bill_stack'

    # schedule
    'Icons.schedule'                  = 'UniconsLine.clock'

    # search
    'Icons.search'                    = 'UniconsLine.search'

    # security
    'Icons.security'                  = 'UniconsLine.shield'

    # send
    'Icons.send'                      = 'UniconsLine.message'

    # settings
    'Icons.settings'                  = 'UniconsLine.cog'

    # share
    'Icons.share_outlined'            = 'UniconsLine.share_alt'
    'Icons.share'                     = 'UniconsLine.share_alt'

    # shield
    'Icons.shield_outlined'           = 'UniconsLine.shield'
    'Icons.shield'                    = 'UniconsLine.shield'

    # smartphone
    'Icons.smartphone'                = 'UniconsLine.mobile_android'

    # swap
    'Icons.swap_horiz'                = 'UniconsLine.exchange_alt'

    # sync / refresh
    'Icons.sync'                      = 'UniconsLine.sync'
    'Icons.refresh'                   = 'UniconsLine.sync'

    # task
    'Icons.task_alt'                  = 'UniconsLine.check_circle'

    # trending
    'Icons.trending_up_rounded'       = 'UniconsLine.chart_line'

    # update
    'Icons.update'                    = 'UniconsLine.history'

    # upload
    'Icons.upload_file'               = 'UniconsLine.file_upload_alt'

    # verified (longest first)
    'Icons.verified_user_outlined'    = 'UniconsLine.shield_check'
    'Icons.verified_user'             = 'UniconsLine.shield_check'
    'Icons.verified'                  = 'UniconsLine.shield_check'

    # videocam
    'Icons.videocam_off'              = 'UniconsLine.video_slash'

    # visibility
    'Icons.visibility_off'            = 'UniconsLine.eye_slash'

    # warning
    'Icons.warning_amber_outlined'    = 'UniconsLine.exclamation_triangle'
    'Icons.warning_amber_rounded'     = 'UniconsLine.exclamation_triangle'
    'Icons.warning_amber'             = 'UniconsLine.exclamation_triangle'

    # wb_sunny
    'Icons.wb_sunny_outlined'         = 'UniconsLine.sun'

    # access_time
    'Icons.access_time'               = 'UniconsLine.clock'

    # attach_money
    'Icons.attach_money'              = 'UniconsLine.dollar_alt'
}

$dartFiles = Get-ChildItem -Path $libDir -Recurse -Filter "*.dart"
$totalReplaced = 0
$filesModified = 0

foreach ($file in $dartFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $originalContent = $content
    $fileReplaced = 0

    foreach ($entry in $mapping.GetEnumerator()) {
        $from = [regex]::Escape($entry.Key)
        $matches = [regex]::Matches($content, $from)
        if ($matches.Count -gt 0) {
            $content = [regex]::Replace($content, $from, $entry.Value)
            $fileReplaced += $matches.Count
        }
    }

    if ($fileReplaced -gt 0) {
        # Add unicons import if not present
        $importLine = "import 'package:unicons/unicons.dart';"
        if ($content -notmatch [regex]::Escape($importLine)) {
            # Insert after last import line
            $content = [regex]::Replace($content, "(import '[^']+';(?:\r?\n)(?!import))", "`$1$importLine`n")
            # If that didn't work (e.g. unicons would be first), try inserting after first import
            if ($content -notmatch [regex]::Escape($importLine)) {
                $content = [regex]::Replace($content, "(import '[^']+';)", "`$1`n$importLine", [System.Text.RegularExpressions.RegexOptions]::None)
                # Remove duplicate imports if inserted multiple times
                $lines = $content -split "`n"
                $seen = @{}
                $deduped = @()
                foreach ($line in $lines) {
                    $trimmed = $line.Trim()
                    if ($trimmed -eq $importLine) {
                        if (-not $seen.ContainsKey($trimmed)) {
                            $seen[$trimmed] = $true
                            $deduped += $line
                        }
                    } else {
                        $deduped += $line
                    }
                }
                $content = $deduped -join "`n"
            }
        }

        # Remove 'flutter/material.dart' Icons dependency note — keep material import (needed for widgets)
        $enc = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($file.FullName, $content, $enc)
        Write-Host "  [$fileReplaced icons] $($file.FullName.Replace($libDir, 'lib'))"
        $totalReplaced += $fileReplaced
        $filesModified++
    }
}

Write-Host ""
Write-Host "Done: $totalReplaced icon replacements across $filesModified files."
