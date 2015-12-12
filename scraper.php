<?php
# Wollondilly Shire Council scraper
require 'scraperwiki.php';
require 'simple_html_dom.php';
date_default_timezone_set('Australia/Sydney');


## Get Cookies
function get_cookies($terms_url) {
    $curl = curl_init($terms_url);
    curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($curl, CURLOPT_HEADER, TRUE);
    $terms_response = curl_exec($curl);
    curl_close($curl);

    preg_match_all('/^Set-Cookie:\s*([^;]*)/mi', $terms_response, $matches);
    $cookies = array();
    foreach($matches[1] as $item) {
        parse_str($item, $cookie);
        $cookies = array_merge($cookies, $cookie);
    }
    return $cookies;
}


###
### Main code start here
###
$url_base = "https://ecouncil.wollondilly.nsw.gov.au";
$term_url = "https://ecouncil.wollondilly.nsw.gov.au/eservice/dialog/daEnquiryInit.do?nodeNum=40801";
$info_url = "https://ecouncil.wollondilly.nsw.gov.au/eServeHome.htm";           # Provide this one to PlanningAlerts users so it requires accept terms etc

    # Default to 'thisweek', use MORPH_PERIOD to change to 'thismonth' or 'lastmonth' for data recovery
    switch(getenv('MORPH_PERIOD')) {
        case 'thismonth' :
            $period = 'thismonth';
            // Current timestamp is assumed, so these find first and last day of THIS month
            $start_date = date('01/m/Y'); // hard-coded '01' for first day
            $end_date   = date('t/m/Y');
            break;
        case 'lastmonth' :
            $start_date = date("01/m/Y", strtotime("first day of previous month"));
            $end_date   = date("t/m/Y", strtotime("last day of previous month"));
            break;
        default         :
            $start_date = date('d/m/Y', time()-7*24*60*60);
            $end_date   = date('d/m/Y');
            break;
    }
    $period = '&dateFrom=' .urlencode($start_date). '&dateTo=' .urlencode($end_date);


$da_page = $url_base . "/eservice/dialog/daEnquiry.do?lodgeRangeType=on" .$period. "&searchMode=A&submitButton=Search";
$cookies = get_cookies($term_url);

# Manually set cookie's key and ready for future use
$request = array(
    'http'    => array(
    'header'  => "Cookie: JSESSIONID_live=" .$cookies['JSESSIONID_live']. "; path=/\r\n"
    ));
$context = stream_context_create($request);

# Get the data that I want within the page
$dom = file_get_html($da_page, false, $context);

# Data from the main page just too hard to work with, 
# Get the indivual DA page and work from there
foreach($dom->find("a[class=plain_header]") as $ref_link ) {
    $actual_da_page = $url_base . $ref_link->href;
    $actual_da_page_dom = file_get_html($actual_da_page, false, $context);

    $application = array('council_reference' => '', 'address' => '', 'description' => '', 'info_url' => '', 
                         'comment_url' => '', 'date_scraped' => '', 'date_received' => '');
    $key = '';
    foreach($actual_da_page_dom->find('p[class=rowDataOnly]') as $gem) {
        if (!is_null($gem->find("span[class=key]", 0))) {
            $key = trim($gem->find("span[class=key]", 0)->plaintext);
        }
        if (!is_null($gem->find("span[class=inputField]", 0))) {
            $value = preg_replace('/\s+/', ' ', trim($gem->find("span[class=inputField]", 0)->plaintext));
        }

        switch ($key) {
            case 'Application No.' :
                $application['council_reference'] = $value;
                break;            
            case 'Property Details' :
                $application['address'] = $value . ", Australia";
                break;
            case 'Type of Work' :
                $application['description'] = html_entity_decode($value);
                break;
            case 'Date Lodged' :
                $date_received = explode('/', $value);
                $date_received = "$date_received[2]-$date_received[1]-$date_received[0]";    
                $date_received = date('Y-m-d', strtotime($date_received));             
                $application['date_received'] = $date_received;
                break;                
        }
    }
    $application['info_url'] = $info_url;
    $application['comment_url'] = $info_url;
    $application['date_scraped'] = date('Y-m-d');

    # Check if record exist, if not, INSERT, else do nothing
    $existingRecords = scraperwiki::select("* from data where `council_reference`='" . $application['council_reference'] . "'");
    if ((count($existingRecords) == 0) && ($application['council_reference'] !== 'Not on file')) {
        print ("Saving record " . $application['council_reference'] . "\n");
        # print_r ($application);
        scraperwiki::save(array('council_reference'), $application);
    } else {
        print ("Skipping already saved record or ignore corrupted data - " . $application['council_reference'] . "\n");
    }

}


?>
