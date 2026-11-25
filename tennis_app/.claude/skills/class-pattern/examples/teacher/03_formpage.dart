import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/models/login_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FormPage extends StatefulWidget{
  const FormPage ({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _formKey = GlobalKey<FormState>();
    int _passwordLength = 0;
    bool _showPassword = false;
    String? _username;
    String? _password;

  String? _validateTextField(String fieldName, String? value, int lenght) {
    if (value!.isEmpty) {
      return '$fieldName must not be empty';
    }

    if (value.length <= lenght) {
      return '$fieldName must be longer than $lenght chars';
    }

    return null;
  }


@override
  void initState() {
    super.initState();
    _username = context.read<LoginModel>().username;
}





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Form Page'),
      ),
      body: Form(
        key: _formKey,
        child: Column (
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                initialValue: _username,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  icon: Icon(Icons.person),
                  hintText: 'What is your username?',
                  labelText: 'Username',
                ),
                onSaved: (newValue) {
                  _username = newValue;
                },

                validator: (value) {
                  return _validateTextField('Username', value, 5);
                },
                      
              ),
            ),
             Padding(
               padding: const EdgeInsets.all(8.0),
               child: TextFormField(
                
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  icon: Icon(Icons.password),
                  hintText: 'What is your password?',
                  labelText: 'Password',
                  suffixText: '$_passwordLength',
                  suffixIcon: GestureDetector(
                    child:Icon(Icons.remove_red_eye),
                    onLongPress: () async {
                      setState(() {
                        _showPassword = true;
                      });

                      await Future.delayed(Duration(
                        seconds: 5
                      ));

                      setState(() {
                        _showPassword = false;
                      });
                    },
                  ),
                ),
                onSaved: (newValue) {
                  _password = newValue;
                },

                onChanged: (value) {
                  setState(() {
                    _passwordLength = value.length;
                  });
                  },
                validator: (value) {
                  return _validateTextField('Password', value, 3);
                },
              ),
             ),
             ElevatedButton(
              child: Text('Login'),
              onPressed: () async {
                if(!_formKey.currentState!.validate()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Input is not valid'))
                  );

                  return;

                }

                _formKey.currentState!.save();

                var loginMessage = '';

                try {
                  final credential = await FirebaseAuth.instance
                  .signInWithEmailAndPassword(
                    email: _username!,
                    password: _password!,
                  );

                loginMessage = 'Signed in successfully ${credential.user?.uid}';


                } on FirebaseAuthException catch (e) {
                  loginMessage = 'Error ${e.message}';
                }


                context.read<LoginModel>().username = _username;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loginMessage),
                    ),
                );
              },
             ),
             ElevatedButton(
              child: Text('Log out'),
              onPressed: () => FirebaseAuth.instance.signOut(),
             ),
          ],
        ), 
      ),
    );
  }
}