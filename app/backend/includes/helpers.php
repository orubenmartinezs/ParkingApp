<?php
// includes/helpers.php

// Note: Timezone should be set via initSystemSettings() in init_settings.php before calling these functions if strictly necessary,
// but for formatting timestamps, as long as date_default_timezone_set is called somewhere early, we are good.

function formatDateSpanish($timestamp, $includeTime = true) {
    if (!$timestamp) return '-';
    
    // Handle milliseconds
    if ($timestamp > 1000000000000) $timestamp /= 1000;
    
    // Sanity check for future dates (e.g., > 2030)
    // If date is too far in future, mark as potential error or just show it
    // But for "Today" lists, we might want to filter them out in the query.
    // Here we just format what we are given.
    
    $days = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
    $months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    
    $dayOfWeek = $days[date('w', $timestamp)];
    $day = date('j', $timestamp);
    $month = $months[date('n', $timestamp) - 1];
    $year = date('Y', $timestamp);
    
    $datePart = "$dayOfWeek, $day $month $year";
    
    if ($includeTime) {
        $time = date('H:i', $timestamp);
        return "$datePart $time";
    }
    
    return $datePart;
}

function formatDateSpanishShort($timestamp) {
    if (!$timestamp) return '-';
    if ($timestamp > 1000000000000) $timestamp /= 1000;
    
    $months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    
    $day = date('j', $timestamp);
    $month = $months[date('n', $timestamp) - 1];
    
    return "$day $month";
}
