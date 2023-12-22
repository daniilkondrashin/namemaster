from flask_wtf import FlaskForm
from wtforms import StringField
from wtforms.validators import Length, DataRequired

class Name(FlaskForm):
    name = StringField("Name: ", validators=[Length(min=3, max=15), DataRequired()])
    