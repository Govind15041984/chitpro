from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    DATABASE_URL: str
    RAZORPAY_KEY_ID: str
    RAZORPAY_KEY_SECRET: str

    # This line is the "bridge" that connects Pydantic to your .env file
    model_config = SettingsConfigDict(env_file=".env")

settings = Settings()