# Wollondilly Shire Council Scraper

Wollondilly Shire Council involves the followings
* Server - .NET but Java backend - Slow, slow, slow
* Cookie tracking - Yes - JSESSION
* Pagnation - No - However, query is based on 'date' submit via POST
* Javascript - No
* Clearly defined data within a row - No and it is so bad that I need to make an extra call to the actual DA to read information
* iFrame - Why??
* Address field all mass up if multiple addresses to a single DA

Setup MORPH_PERIOD for data recovery, available options are
* thisweek (default)
* thismonth
* lastmonth

Enjoy
