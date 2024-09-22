#!/bin/bash                                                               
                                                                          
find .  -type f \( -name "*.md" -o -name "*.txt" \) -print0 | while read -d $'\0' file           
do                                                                        
sed -i -e  '/^#####[a-zA-Z0-9\/]/ s/#####/##### /' "${file}"                                     
sed -i -e  '/^####[a-zA-Z0-9\/]/ s/####/#### /' "${file}"                                     
sed -i -e  '/^###[a-zA-Z0-9\/]/ s/###/### /' "${file}"                                     
sed -i -e  '/^##[a-zA-Z0-9\/]/ s/##/## /' "${file}"                                     
sed -i -e  '/^#[a-zA-Z0-9\/]/ s/#/# /' "${file}"                                     
                
done       
