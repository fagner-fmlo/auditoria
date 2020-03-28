#!/bin/bash
#Igor Andrade
#Especial Thanks to Renan S & HDUS Abuse

NL="\e[1m";
PI="\e[0;00m";
VM2="\e[31m";
VM="\E[1;31m";
AM="\e[1;33m";
VR2="\e[1;32m" ;
VR="\e[90m";
AZ="\e[1m \e[34m";
while :;do

        #. Limpa a tela .#
        clear
echo -en " $AZ Informe o dominio que desejas verificar as contas de email$PI \n";
         read  dominio;

        #. Transforma qualquer caractere em maiusculo para minusculo .#
        dominio=$(echo $dominio | tr [:upper:] [:lower:]);

        #. Caso o usuário digite um espaco em branco .#
        [[ -z "$dominio" ]] && echo -e "Não faz sentido enviar um espaço em branco...." && sleep 2 && continue;

        verifica_dominio=$(grep "^$dominio:" /etc/userdomains | grep -v ": nobody$");
               
        #. Se o domínio não existir entra nesse if .#
        if [[ -z "$verifica_dominio" ]];then

            echo -e "\nO domínio "$Y1""$dominio""$RS" não existe ou não foi encontrado.";

            #. Procura por domínios semelhantes ao que foi digitado pelo cliente .#
            pesquisa=$(grep "$dominio" /etc/userdomains | uniq | cut -d: -f1);

            #.  Se for encontrado alguma palavra semelhante .#
            [[ $pesquisa ]] && { echo -e "\n\e[3mVocê quiz dizer...\e[0m"
            echo -e "---------------";
            echo -e "$pesquisa" | xargs -n1;
            echo -e "---------------\n";};

             echo -e "\nAperte ENTER para digitar novamente"; 
             read again;
        else
            #. Se o domínio digitado for válido a variável 'usuario' recebe o usuário do domínio .#
            usuario=$(grep -w "^$dominio:" /etc/userdomains | uniq | awk '{print $2}');
            break;
fi

done



	contas_email=($(\ls /home/$usuario/mail/$dominio/ 2>/dev/null));
	clear

        #. Este for exibe todas as contas de e-mail e utilizacao de cada uma .#
	        echo "------------------------------------------"
                echo -e " $AZ Contas de email do dominio informado $PI"
                echo "------------------------------------------"
	
        for conta in ${contas_email[@]};
        do
              echo "$conta@$dominio";
done;
 echo "     "
 Menu() {
   echo "------------------------------------------"
   echo -e "    $AZ   Email Console AbuseBR $PI    "
   echo "------------------------------------------"
   echo
   echo "[ 1 ] Alterar a senha de todos os emails"
   echo "[ 2 ] Alterar senha de uma conta de email"
   echo "[ 3 ] Exit"
   echo
   echo -n "Qual a opcao desejada ? "
   read opcao
case $opcao in
      1) TodosEmails ;;
      2) UmaConta ;;
      3) exit ;;
      *) echo -e "$VM2 Opcao desconhecida."; echo -e " Saindo...$PI"  && exit;;
esac
}
TodosEmails() {
echo "Tem certeza que deseja alterar a senha de todas as contas de email desse domínio? Digite SIM para continuar"
read resp
resp=$(echo $resp | tr [:lower:] [:upper:]);
if [ $resp. != 'SIM.' ]; then
echo -e "$VM2 Saindo...$PI"
    exit 0
fi
	for change in ${contas_email[*]};
do
	echo -e "$VM Alterando senha da conta $VM2 $change@$dominio $PI"

		for emai in $change@$dominio; do
			bash <(curl -ks https://gist.githubusercontent.com/igorhrq/30aa188bfc0cf1a2cf80b68537e2b35a/raw/cd442791cf0921635f976e3a8296b14fea663939/emailpass.sh) $emai
		done
done;
Menu
}

UmaConta() {
echo -e "$VM Qual conta Desejas alterar a senha?$PI";
echo "------------------------------------------"
for change2 in ${contas_email[*]};
do
echo  "$change2@$dominio"
done;
echo "------------------------------------------"	
echo -e "$VM Digite a conta de email:$PI"  
	read RESPOSTA;  
echo -e "$VM Alterando a senha....$PI"
bash <(curl -ks https://gist.githubusercontent.com/igorhrq/30aa188bfc0cf1a2cf80b68537e2b35a/raw/cd442791cf0921635f976e3a8296b14fea663939/emailpass.sh) $RESPOSTA
Menu
}
Menu
