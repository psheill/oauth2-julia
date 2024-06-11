This is simply a way to do Oauth2 authentication from Julia, as you might want to use to access data from Google Sheets.

Example settings:

const TOKEN_URL = "https://oauth2.googleapis.com/token"
const TEST_TOKEN_URL = "https://www.googleapis.com/oauth2/v3/tokeninfo?access_token="
const AUTH_URL = "https://accounts.google.com/o/oauth2/auth"
const REDIRECT_URI = "http://localhost:8080"
const SCOPE = "https://www.googleapis.com/auth/spreadsheets.readonly"

