pragma solidity 0.6.2;
//pragma experimental ABIEncoderV2;

contract integrityCertifier {

// PACKAGE FOR DATE GENERATION FROM UNIX TIMESTAMP TO GMT READABLE FORMAT ------------------------------------------------

        //Local struct used as current date buffer
        struct _DateTime {
                uint16 year;
                uint8 month;
                uint8 day;
                uint8 hour;
                uint8 minute;
                uint8 second;
                uint8 weekday;
        }

        //Local constants used in calculations
        uint constant YEAR_IN_SECONDS = 31536000;
        uint constant LEAP_YEAR_IN_SECONDS = 31622400;
        uint constant DAY_IN_SECONDS = 86400;
        uint constant HOUR_IN_SECONDS = 3600;
        uint constant MINUTE_IN_SECONDS = 60;
        uint16 constant ORIGIN_YEAR = 1970;

        //////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Functions to call to convert from timestamp to GMT human readable format time
        //////////////////////////////////////////////////////////////////////////////////////////////////////////

         function getYear(uint timestamp) internal pure returns (uint16 year) {
                uint secondsAccountedFor = 0;
                uint numLeapYears;

                year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);                   // Year
                numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);
                secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
                secondsAccountedFor += YEAR_IN_SECONDS * (year - ORIGIN_YEAR - numLeapYears);
                while (secondsAccountedFor > timestamp) {
                        if (isLeapYear(uint16(year - 1))) {
                                secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
                        }
                        else {
                                secondsAccountedFor -= YEAR_IN_SECONDS;
                        }
                        year -= 1;
                }
                return year;
        }

        function getMonth(uint timestamp) internal pure returns (uint8)     { return parseTimestamp(timestamp).month; }
        function getDay(uint timestamp) internal pure returns (uint8)       { return parseTimestamp(timestamp).day; }
        function getHour(uint timestamp) internal pure returns (uint8)      { return uint8((timestamp / 60 / 60) % 24); }
        function getMinute(uint timestamp) internal pure returns (uint8)    { return uint8((timestamp / 60) % 60); }
        function getSecond(uint timestamp) internal pure returns (uint8)    { return uint8(timestamp % 60); }
        function getWeekday(uint timestamp) internal pure returns (uint8)   { return uint8((timestamp / DAY_IN_SECONDS + 4) % 7); }

        //////////////////////////////////////////////////////////////////////////////////////////////////////////
        // SLAVE FUNCTIONS
        //////////////////////////////////////////////////////////////////////////////////////////////////////////

        function parseTimestamp(uint timestamp) internal pure returns (_DateTime memory dt) {

                uint secondsAccountedFor = 0; uint buf; uint8 i;

                dt.year = getYear(timestamp);                                               // Year
                buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);
                secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
                secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

                uint secondsInMonth;                                                        // Month
                for (i = 1; i <= 12; i++) {
                        secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
                        if (secondsInMonth + secondsAccountedFor > timestamp) {
                                dt.month = i;
                                break;
                        }
                        secondsAccountedFor += secondsInMonth;
                }

                for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) {                  // Day
                        if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) {
                                dt.day = i;
                                break;
                        }
                        secondsAccountedFor += DAY_IN_SECONDS;
                }

                dt.hour = getHour(timestamp);                                               // Hour
                dt.minute = getMinute(timestamp);                                           // Minute
                dt.second = getSecond(timestamp);                                           // Second
                dt.weekday = getWeekday(timestamp);                                         // Day of week.
        }

        function isLeapYear(uint16 year) internal pure returns (bool) {
                if (year % 4 != 0) return false;
                if (year % 100 != 0) return true;
                if (year % 400 != 0) return false;
                return true;
        }

        function leapYearsBefore(uint year) internal pure returns (uint) {
                year -= 1;
                return year / 4 - year / 100 + year / 400;
        }

        function getDaysInMonth(uint8 month, uint16 year) internal pure returns (uint8) {
                if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
                        return 31;
                }
                else if (month == 4 || month == 6 || month == 9 || month == 11) {
                        return 30;
                }
                else if (isLeapYear(year)) {
                        return 29;
                }
                else {
                        return 28;
                }
        }
        //////////////////////////////////////////////////////////////////////////////////////////////////////////

        // PACKAGE FOR BLOCKCHAIN LEDGER READ AND WRITE  ------------------------------------------------
        struct  CertifiedFile {

            // CERTIFICATION INFORMATION PART
            uint    _uploadCertifiedDate;  // certified date of the record writing on the blockchain (UNIX seconds from 1970 format, GMT)
            uint16  _year;
            uint8   _month;
            uint8   _day;
            uint8   _UTC_hour;
            uint8   _minute;
            uint8   _second;
            bytes32 _hash;        //SHA256 hash of the file (for integrity check, available as standard in the WIN10 GUI)
            string  _fileName;    // Original filename when issued (in the company)
            string  _issueDate;   // Date of emission (in the company)
            string  _title;       // Title of the document
            string  _office;      // Emitting office (in the company)
        }
        CertifiedFile private bufCF;
        mapping (bytes32 => CertifiedFile) private ledger;       // The true blockchain based ledger
        address private owner;
        bytes32 private magickey;

        // getKeyFromPassword() - this is a service only function, to be used once BEFORE mainet deploy to calculate the magickey
        // value to write into the constructor.
        // IMPORTANT NOTICE: during all the debug time, the passord must be:                    , to which is corresponding
        // the 0xcd9aa6893e249922342bc08eafefb487b0e0ca72ac5164c8a36dfa999a987250 magickey value
        //
        function getKeyFromPassword(string memory password) internal pure returns(bytes32 _magickey) {
                _magickey = sha256(abi.encodePacked(password));
        }

        constructor () public {
        owner = msg.sender;
        magickey = 0xcd9aa6893e249922342bc08eafefb487b0e0ca72ac5164c8a36dfa999a987250;
        }

        receive() external payable {        // just to unable people to store money here
            revert();
        }

        // killTheLedger() - used to clear blockchain of all the information stored before and kill this smart contract
        function killTheLedger(address payable recipient, string memory password) public {
            require(msg.sender == owner);
            require(recipient != payable(0x0));
            require(sha256(abi.encodePacked(password)) == magickey);
            selfdestruct(recipient);
        }

        //@title storeLedger()
        //@author R.P.
        //@notice The function to call in order to register any issued file in the permanent blockchain ledger
        //@param key The sha256 CRC code calculated on the issued file (this is a standard function available in Win10)
        //@param fileName The original filename of the document
        //@param issueDate The file issue date, formatted as DD/MM/YYYY
        //@param title The title of the document (in the issued file)
        //@param office The AEN office which issued the document
        function storeLedger(bytes32 key, string memory fileName, string memory issueDate, string memory title, string memory office) public
        {
            // check the possible existence of a previously recorded document (unable to record twice the same document!)
            require(ledger[key]._uploadCertifiedDate == uint (0x0), "Error: this record is already present!");
            // certificate the store time as measured at Ethereum nodes
            bufCF._uploadCertifiedDate = block.timestamp;
            // copy the input data in the buffer struct
            bufCF._fileName = fileName;
            bufCF._issueDate = issueDate;
            bufCF._title = title;
            bufCF._office = office;
            bufCF._hash = key;
            // calculate the human readable format of the certified date and store it in the struct
            bufCF._year = getYear(bufCF._uploadCertifiedDate);
            bufCF._month = getMonth(bufCF._uploadCertifiedDate);
            bufCF._day = getDay(bufCF._uploadCertifiedDate);
            bufCF._UTC_hour = getHour(bufCF._uploadCertifiedDate);
            bufCF._minute = getMinute(bufCF._uploadCertifiedDate);
            bufCF._second = getSecond(bufCF._uploadCertifiedDate);
            // add a record to the blockchain ledger corresponding to the current document to be certified as described in the struct
            ledger[key] = bufCF;
        }

        function readLedger(bytes32 key) view public
        returns (uint uploadCertifiedDate, uint16  year, uint8 month, uint8 day, uint8  UTC_hour, uint8 minute, uint8 second, string memory fileName, string memory issueDate, string  memory title, string  memory office)
        {
                // check the existence of the requested record
                require(ledger[key]._uploadCertifiedDate != uint (0x0), "Error: this record is not present!");
                uploadCertifiedDate   = ledger[key]._uploadCertifiedDate;
                year            = ledger[key]._year;
                month           = ledger[key]._month;
                day             = ledger[key]._day;
                UTC_hour        = ledger[key]._UTC_hour;
                minute          = ledger[key]._minute;
                second          = ledger[key]._second;
                fileName        = ledger[key]._fileName;
                issueDate       = ledger[key]._issueDate;
                title           = ledger[key]._title;
                office          = ledger[key]._office;
        }
}       // contract end
