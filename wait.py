import PySimpleGUI as sg

def main():
    layout = [[[sg.Text("Stepper: "),sg.Button('Next')]]]
    window = sg.Window('Window Title', layout)    
    window.read()    
    window.close()
    
if __name__=="__main__":
    main()
