""" Constants """
from typing import Optional
import voluptuous as vol
from datetime import datetime
import homeassistant.helpers.config_validation as cv
from homeassistant.const import CONF_NAME


# Base component constants
DOMAIN = "anniversaries"
DOMAIN_DATA = f"{DOMAIN}_data"
VERSION = "1.0.0"
PLATFORM = "sensor"
ISSUE_URL = "https://github.com/pinkywafer/Anniversaries/issues"
ATTRIBUTION = "Sensor data calculated by Anniversaries Integration"

CALENDAR_NAME = "Anniversaries"
SENSOR_PLATFORM = "sensor"
CALENDAR_PLATFORM = "calendar"

ATTR_YEARS_NEXT = "years_at_next_anniversary"
ATTR_YEARS_CURRENT = "current_years"
ATTR_DATE = "date"

# Device classes
BINARY_SENSOR_DEVICE_CLASS = "connectivity"

# Configuration
CONF_SENSOR = "sensor"
CONF_ENABLED = "enabled"
CONF_DATE = "date"
CONF_DATE_TEMPLATE = "date_template"
CONF_ICON_NORMAL = "icon_normal"
CONF_ICON_TODAY = "icon_today"
CONF_ICON_SOON = "icon_soon"
CONF_DATE_FORMAT = "date_format" # Deprecated
CONF_SENSORS = "sensors"
CONF_SOON = "days_as_soon"
CONF_HALF_ANNIVERSARY = "show_half_anniversary"
CONF_UNIT_OF_MEASUREMENT = "unit_of_measurement"
CONF_ID_PREFIX = "id_prefix"
CONF_ONE_TIME = "one_time"
CONF_COUNT_UP = "count_up"
CONF_CALENDAR_TYPE = "calendar_type"
CONF_DATE_EXCLUSION_ERROR = "Configuration cannot include both `date` and `date_template`. configure ONLY ONE"
CONF_DATE_REQD_ERROR = "Either `date` or `date_template` is Required"

# Calendar Types
CALENDAR_TYPE_GREGORIAN = "gregorian"
CALENDAR_TYPE_HEBREW = "hebrew"

# Defaults
DEFAULT_NAME = DOMAIN
DEFAULT_ICON_NORMAL = "mdi:calendar-blank"
DEFAULT_ICON_TODAY = "mdi:calendar-star"
DEFAULT_ICON_SOON = "mdi:calendar"
DEFAULT_DATE_FORMAT = "%Y-%m-%d" # Deprecated
DEFAULT_SOON = 1
DEFAULT_HALF_ANNIVERSARY = False
DEFAULT_UNIT_OF_MEASUREMENT = "Days"
DEFAULT_ID_PREFIX = "anniversary_"
DEFAULT_ONE_TIME = False
DEFAULT_COUNT_UP = False
DEFAULT_CALENDAR_TYPE = CALENDAR_TYPE_GREGORIAN

ICON = DEFAULT_ICON_NORMAL

def check_date(value):
    try:
        datetime.strptime(value, "%Y-%m-%d")
        return value
    except ValueError:
        pass
    try:
        datetime.strptime(value, "%m-%d")
        return value
    except ValueError:
        raise vol.Invalid(f"Invalid date: {value}")

def validate_hebrew_date(value):
    """Validate Hebrew date format and return it if valid."""
    try:
        import hdate
    except ImportError:
        raise vol.Invalid("hdate library not available for Hebrew calendar support")
    
    # Try format: DD-MM-YYYY (Hebrew date)
    try:
        parts = value.split("-")
        if len(parts) == 3:
            day = int(parts[0])
            month = int(parts[1])
            year = int(parts[2])
            # Validate by creating HDate object
            hdate.HDate(day, month, year)
            return value
    except (ValueError, AttributeError):
        pass
    
    # Try format: DD-MM (Hebrew date without year)
    try:
        parts = value.split("-")
        if len(parts) == 2:
            day = int(parts[0])
            month = int(parts[1])
            # Validate month is in valid range (1-13 for leap years)
            if 1 <= month <= 13 and 1 <= day <= 30:
                return value
    except (ValueError, AttributeError):
        pass
    
    # Try format: "DD MonthName YYYY" or "DD MonthName" (e.g., "15 Adar 5745")
    try:
        parts = value.split()
        if len(parts) >= 2:
            day = int(parts[0])
            month_name = parts[1]
            year = int(parts[2]) if len(parts) == 3 else None
            
            # Map month names to numbers (supporting both Hebrew and English transliterations)
            month_map = {
                "Tishrei": 1, "תשרי": 1,
                "Cheshvan": 2, "Marcheshvan": 2, "חשוון": 2, "מרחשוון": 2,
                "Kislev": 3, "כסלו": 3,
                "Tevet": 4, "טבת": 4,
                "Shevat": 5, "שבט": 5,
                "Adar": 6, "אדר": 6,
                "Adar1": 13, "Adar I": 13, "אדר א": 13,
                "Adar2": 14, "Adar II": 14, "אדר ב": 14,
                "Nisan": 7, "ניסן": 7,
                "Iyar": 8, "אייר": 8,
                "Sivan": 9, "סיוון": 9,
                "Tammuz": 10, "תמוז": 10,
                "Av": 11, "אב": 11,
                "Elul": 12, "אלול": 12,
            }
            
            month_num = month_map.get(month_name)
            if month_num and year:
                # Validate by creating HDate object
                hdate.HDate(day, month_num, year)
                return value
            elif month_num and not year:
                # Valid month and day without year
                if 1 <= day <= 30:
                    return value
    except (ValueError, KeyError, AttributeError):
        pass
    
    raise vol.Invalid(f"Invalid Hebrew date: {value}. Use format DD-MM-YYYY, DD-MM, or 'DD MonthName YYYY'")

DATE_SCHEMA = vol.Schema(
    {
        vol.Required(
            vol.Any(CONF_DATE,CONF_DATE_TEMPLATE,msg=CONF_DATE_REQD_ERROR)
        ): object
    }, extra=vol.ALLOW_EXTRA
)

SENSOR_CONFIG_SCHEMA = vol.All(
    # Deprecated - will be removed in future version
    cv.deprecated(CONF_DATE_FORMAT),
    vol.Schema(
        {
            vol.Required(CONF_NAME): cv.string,
            vol.Exclusive(CONF_DATE, CONF_DATE, msg=CONF_DATE_EXCLUSION_ERROR): cv.string,
            vol.Exclusive(CONF_DATE_TEMPLATE, CONF_DATE, msg=CONF_DATE_EXCLUSION_ERROR): cv.string,
            vol.Optional(CONF_CALENDAR_TYPE, default=DEFAULT_CALENDAR_TYPE): vol.In([CALENDAR_TYPE_GREGORIAN, CALENDAR_TYPE_HEBREW]),
            vol.Optional(CONF_SOON, default=DEFAULT_SOON): cv.positive_int,
            vol.Optional(CONF_ICON_NORMAL, default=DEFAULT_ICON_NORMAL): cv.icon,
            vol.Optional(CONF_ICON_TODAY, default=DEFAULT_ICON_TODAY): cv.icon,
            vol.Optional(CONF_ICON_SOON, default=DEFAULT_ICON_SOON): cv.icon,
            vol.Optional(CONF_DATE_FORMAT, default=DEFAULT_DATE_FORMAT): cv.string,
            vol.Optional(CONF_HALF_ANNIVERSARY, default=DEFAULT_HALF_ANNIVERSARY): cv.boolean,
            vol.Optional(CONF_UNIT_OF_MEASUREMENT, default=DEFAULT_UNIT_OF_MEASUREMENT): cv.string,
            vol.Optional(CONF_ID_PREFIX, default=DEFAULT_ID_PREFIX): cv.string,
            vol.Optional(CONF_ONE_TIME, default=DEFAULT_ONE_TIME): cv.boolean,
            vol.Optional(CONF_COUNT_UP, default=DEFAULT_COUNT_UP): cv.boolean,
        }
    )
)

SENSOR_SCHEMA = vol.All(SENSOR_CONFIG_SCHEMA, DATE_SCHEMA)

CONFIG_SCHEMA = vol.Schema(
    {
        DOMAIN: vol.Schema(
            {vol.Optional(CONF_SENSORS): vol.All(cv.ensure_list, [SENSOR_SCHEMA])}
        )
    },
    extra=vol.ALLOW_EXTRA,
)
