from collections import namedtuple


from flask import Flask, render_template, redirect, url_for, request
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import desc
from form import Name

app = Flask(__name__)




app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql+psycopg2://postgres:68017346@localhost/namemaster'
app.config['SECRET_KEY'] = '3f6f301d28743848cdabfce5dca93a92'  
db = SQLAlchemy(app)

Messages = namedtuple('Messages', 'text')
messagesSession = []


class Message(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    text = db.Column(db.String(1024), nullable=True)
        
    def __init__(self, text):
        self.text = text.strip()


with app.app_context():
    db.create_all()


@app.route('/', methods=['GET'])
def hello_world():
    return render_template('index.html')


@app.route("/main", methods=['POST', 'GET'])
def main():
    form = Name()
    if form.validate_on_submit():
        text = form.name.data
        messagesSession.append(Messages(text))

        db.session.add(Message(text))
        db.session.commit()
        return redirect(url_for('main'))
    return render_template('main.html', messagesSession=messagesSession, messages=Message.query.order_by(desc(Message.id)).limit(5).all(), form=form)

@app.route("/delete_data", methods=['POST'])
def delete_data():
    if request.method == 'POST':
        db.session.query(Message).delete()
        db.session.commit()
        return redirect(url_for('main'))