"""
Weather Estimation Module

Provides temperature estimation for shooting events based on location and date.
This module replicates the logic originally implemented in the iOS app,
centralizing it in the data loading pipeline.
"""

import pandas as pd
from datetime import datetime
from typing import Tuple, Optional


class WeatherEstimator:
    """Estimates weather conditions for shooting events"""
    
    # Base afternoon high temperatures by month (rough averages for US at 3 PM)
    BASE_HIGH_TEMPS = {
        1: 50, 2: 55, 3: 65, 4: 75, 5: 83, 6: 90,
        7: 93, 8: 92, 9: 85, 10: 75, 11: 63, 12: 53
    }
    
    # Regional temperature adjustments by state
    REGIONAL_ADJUSTMENTS = {
        # Hot states
        'FL': 8, 'TX': 8, 'AZ': 8, 'CA': 8, 'NV': 8,
        # Cold states
        'MT': -8, 'WY': -8, 'ND': -8, 'SD': -8, 'MN': -8, 
        'WI': -8, 'ME': -8, 'VT': -8, 'NH': -8,
        # Pacific Northwest
        'WA': -3, 'OR': -3, 'ID': -3
    }
    
    # Morning temperature difference by season
    SEASONAL_TEMP_DIFFERENCE = {
        'winter': 12,  # Dec, Jan, Feb
        'spring': 18,  # Mar, Apr, Nov
        'summer': 22,  # May, Jun, Jul, Aug, Sep, Oct
        'fall': 18     # (handled by spring case)
    }
    
    @staticmethod
    def get_season_for_month(month: int) -> str:
        """Get season string for temperature difference calculation"""
        if month in [12, 1, 2]:
            return 'winter'
        elif month in [3, 4, 11]:
            return 'spring'
        elif month in [5, 6, 7, 8, 9, 10]:
            return 'summer'
        else:
            return 'spring'  # fallback
    
    @staticmethod
    def calculate_shoot_duration(start_date: datetime, end_date: Optional[datetime]) -> int:
        """Calculate duration of shoot in days"""
        if end_date is None:
            return 1
        
        delta = end_date - start_date
        return max(1, delta.days + 1)
    
    @classmethod
    def estimate_temperatures(cls, start_date: datetime, state: Optional[str] = None) -> Tuple[int, int]:
        """
        Estimate morning and afternoon temperatures for a given date and location
        
        Args:
            start_date: Start date of the shoot
            state: State abbreviation (e.g., 'CA', 'TX', 'FL')
        
        Returns:
            Tuple of (morning_temp, afternoon_temp) in Fahrenheit
        """
        month = start_date.month
        
        # Get base afternoon temperature for the month
        afternoon_high = cls.BASE_HIGH_TEMPS.get(month, 75)
        
        # Apply regional adjustment based on state
        if state and state in cls.REGIONAL_ADJUSTMENTS:
            afternoon_high += cls.REGIONAL_ADJUSTMENTS[state]
        
        # Calculate morning temperature based on season
        season = cls.get_season_for_month(month)
        temp_difference = cls.SEASONAL_TEMP_DIFFERENCE[season]
        
        morning_low = max(afternoon_high - temp_difference, 20)  # Never below 20°F
        
        return (morning_low, afternoon_high)
    
    @classmethod
    def get_temperature_band(cls, temperature: int) -> str:
        """
        Get temperature band for a given temperature
        
        Args:
            temperature: Temperature in Fahrenheit
        
        Returns:
            Temperature band string
        """
        if temperature < 15:
            return 'frigid'
        elif temperature < 32:
            return 'freezing'
        elif temperature < 45:
            return 'very_cold'
        elif temperature < 55:
            return 'cold'
        elif temperature < 65:
            return 'cool'
        elif temperature < 75:
            return 'comfortable'
        elif temperature < 85:
            return 'warm'
        elif temperature < 95:
            return 'hot'
        else:
            return 'sweltering'
    
    @classmethod
    def estimate_weather_for_shoot(cls, shoot_row: pd.Series) -> dict:
        """
        Estimate complete weather data for a shoot
        
        Args:
            shoot_row: Pandas Series containing shoot data
        
        Returns:
            Dictionary with weather estimation data
        """
        try:
            # Parse start date
            start_date_str = shoot_row.get('Start Date', '')
            if pd.isna(start_date_str) or not start_date_str:
                return {}
            
            # Handle different date formats
            try:
                start_date = pd.to_datetime(start_date_str)
            except:
                return {}
            
            # Parse end date
            end_date = None
            end_date_str = shoot_row.get('End Date', '')
            if not pd.isna(end_date_str) and end_date_str:
                try:
                    end_date = pd.to_datetime(end_date_str)
                except:
                    pass
            
            # Get state for regional adjustment
            state = shoot_row.get('State', None)
            if pd.isna(state):
                state = None
            
            # Calculate estimates
            morning_temp, afternoon_temp = cls.estimate_temperatures(start_date, state)
            duration = cls.calculate_shoot_duration(start_date, end_date)
            
            return {
                'shoot_id': shoot_row.get('Shoot ID'),
                'morning_temp_f': morning_temp,
                'afternoon_temp_f': afternoon_temp,
                'morning_temp_c': int((morning_temp - 32) * 5/9),
                'afternoon_temp_c': int((afternoon_temp - 32) * 5/9),
                'duration_days': duration,
                'morning_temp_band': cls.get_temperature_band(morning_temp),
                'afternoon_temp_band': cls.get_temperature_band(afternoon_temp),
                'estimation_method': 'seasonal_regional'
            }
        
        except Exception as e:
            print(f"Error estimating weather for shoot {shoot_row.get('Shoot ID', 'unknown')}: {e}")
            return {}


def add_weather_estimates_to_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """
    Add weather estimation columns to the shoots dataframe
    
    Args:
        df: DataFrame containing shoot data
    
    Returns:
        DataFrame with added weather estimation columns
    """
    weather_data = []
    
    for _, row in df.iterrows():
        weather_estimate = WeatherEstimator.estimate_weather_for_shoot(row)
        weather_data.append(weather_estimate)
    
    # Create weather DataFrame
    weather_df = pd.DataFrame(weather_data)
    
    if not weather_df.empty:
        # Add weather columns to main dataframe
        df = df.merge(weather_df, left_on='Shoot ID', right_on='shoot_id', how='left')
        # Remove duplicate shoot_id column from weather data
        if 'shoot_id' in df.columns:
            df = df.drop('shoot_id', axis=1)
    
    return df